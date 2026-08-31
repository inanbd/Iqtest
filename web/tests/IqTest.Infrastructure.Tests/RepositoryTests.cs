using Dapper;
using IqTest.Application.Abstractions;
using IqTest.Domain.Attempts;
using IqTest.Domain.Questions;
using IqTest.Domain.Scoring;
using IqTest.Infrastructure.Persistence;

namespace IqTest.Infrastructure.Tests;

[Collection(SqlServerCollection.Name)]
public sealed class RepositoryTests(SqlServerFixture sql)
{
    private static readonly TextQuestion Easy = new(
        "t1", QuestionCategory.Numerical, 1, "Easy?", ["a", "b", "c", "d"], 0, "because");

    private static readonly TextQuestion Hard = new(
        "t2", QuestionCategory.Verbal, 5, "Hard?", ["a", "b", "c", "d"], 3, "because");

    /// <summary>
    /// These are integration tests against a real SQL Server. Where none is
    /// reachable they are skipped rather than failed, so the suite still runs
    /// on a machine without one.
    /// </summary>
    private void SkipIfUnavailable() =>
        Skip.IfNot(sql.IsAvailable, $"SQL Server is not reachable: {sql.UnavailableReason}");

    private static Attempt BuildAttempt(
        Participant? participant,
        TestFormat format = TestFormat.Full,
        int correctCount = 2,
        DateTimeOffset? completedAt = null)
    {
        var answers = new List<AnsweredQuestion>
        {
            new(Easy, correctCount >= 1 ? Easy.CorrectIndex : 1),
            new(Hard, correctCount >= 2 ? Hard.CorrectIndex : 0),
        };

        return Attempt.Complete(
            Guid.NewGuid(),
            CertificateSlug.NewSlug(),
            participant,
            format,
            TestPlatform.Web,
            answers,
            TimeSpan.FromMinutes(9),
            completedAt ?? DateTimeOffset.UtcNow);
    }

    private static Participant BuildParticipant(string name, string country = "GB", string? email = null) =>
        Participant.Create(Guid.NewGuid(), name, country, email, DateTimeOffset.UtcNow);

    [SkippableFact]
    public async Task Migrator_creates_every_table_and_can_run_twice()
    {
        SkipIfUnavailable();

        // Idempotence matters: the migrator replays on every start-up.
        await new DatabaseMigrator(sql.Connections, Microsoft.Extensions.Logging.Abstractions.NullLogger<DatabaseMigrator>.Instance)
            .MigrateAsync();

        await using var connection = sql.Connections.Create();
        var tables = (await connection.QueryAsync<string>(
            "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';")).ToHashSet();

        Assert.Contains("Participants", tables);
        Assert.Contains("Attempts", tables);
        Assert.Contains("AttemptCategoryScores", tables);
        Assert.Contains("AttemptAnswers", tables);
        Assert.Contains("Sittings", tables);
        Assert.Contains("SittingItems", tables);
    }

    [SkippableFact]
    public async Task Attempt_round_trips_with_its_participant_scores_and_answers()
    {
        SkipIfUnavailable();
        await sql.ResetAsync();

        var attempt = BuildAttempt(BuildParticipant("Ada", "GB", "ada@example.com"));
        await new AttemptRepository(sql.Connections).AddAsync(attempt, default);

        var certificates = new LeaderboardReadStore(sql.Connections);
        var view = await certificates.FindAsync(attempt.Slug.Value, default);

        Assert.NotNull(view);
        Assert.Equal("Ada", view!.DisplayName);
        Assert.Equal("GB", view.CountryCode);
        Assert.Equal(attempt.Score.Index, view.Index);
        Assert.Equal(attempt.Score.Correct, view.Correct);
        Assert.Equal(attempt.Score.MaxWeightedPoints, view.MaxWeightedPoints);
        Assert.Equal(TimeSpan.FromMinutes(9), view.Duration);
        Assert.True(view.IsRanked);

        // The per-domain breakdown came back too.
        Assert.Equal(2, view.ByCategory.Count);
        Assert.Contains(view.ByCategory, c => c.Category == QuestionCategory.Numerical);
        Assert.Contains(view.ByCategory, c => c.Category == QuestionCategory.Verbal);

        await using var connection = sql.Connections.Create();
        var storedAnswers = await connection.QueryAsync<(string QuestionId, int? SelectedIndex, bool IsCorrect)>(
            "SELECT QuestionId, SelectedIndex, IsCorrect FROM dbo.AttemptAnswers WHERE AttemptId = @id ORDER BY Position;",
            new { id = attempt.Id });
        Assert.Equal(2, storedAnswers.Count());
    }

    [SkippableFact]
    public async Task An_anonymous_attempt_is_stored_but_never_ranked()
    {
        SkipIfUnavailable();
        await sql.ResetAsync();

        var attempt = BuildAttempt(participant: null);
        await new AttemptRepository(sql.Connections).AddAsync(attempt, default);

        var store = new LeaderboardReadStore(sql.Connections);
        var view = await store.FindAsync(attempt.Slug.Value, default);

        Assert.NotNull(view);
        Assert.True(view!.IsAnonymous);
        Assert.False(view.IsRanked);
        Assert.Null(await store.GetRankAsync(attempt.Id, default));

        var page = await store.GetPageAsync(null, 1, 25, default);
        Assert.Empty(page.Rows);
    }

    [SkippableFact]
    public async Task An_unknown_certificate_address_returns_nothing()
    {
        SkipIfUnavailable();
        await sql.ResetAsync();

        var store = new LeaderboardReadStore(sql.Connections);
        Assert.Null(await store.FindAsync(CertificateSlug.NewSlug().Value, default));
    }

    [SkippableFact]
    public async Task A_sitting_round_trips_with_its_answers()
    {
        SkipIfUnavailable();
        await sql.ResetAsync();

        var repository = new SittingRepository(sql.Connections);
        var started = DateTimeOffset.UtcNow;
        var sitting = new Sitting(
            Guid.NewGuid(), TestFormat.Quick, ["n1", "v1", "l1", "s1"],
            started, started.AddMinutes(12), "visitor-1");

        await repository.CreateAsync(sitting, default);
        await repository.SaveAnswerAsync(sitting.Id, 2, 3, default);

        var loaded = await repository.FindAsync(sitting.Id, default);

        Assert.NotNull(loaded);
        Assert.Equal(TestFormat.Quick, loaded!.Format);
        Assert.Equal(new[] { "n1", "v1", "l1", "s1" }, loaded.QuestionIds);
        Assert.Equal(new int?[] { null, null, 3, null }, loaded.Answers);
        Assert.False(loaded.IsSubmitted);

        await repository.MarkSubmittedAsync(sitting.Id, started.AddMinutes(5), default);
        Assert.True((await repository.FindAsync(sitting.Id, default))!.IsSubmitted);
    }

    [SkippableFact]
    public async Task A_returning_visitor_gets_the_items_of_their_last_sitting_held_back()
    {
        SkipIfUnavailable();
        await sql.ResetAsync();

        var repository = new SittingRepository(sql.Connections);
        var now = DateTimeOffset.UtcNow;

        await repository.CreateAsync(
            new Sitting(Guid.NewGuid(), TestFormat.Quick, ["n1", "v1"], now.AddHours(-2), now, "visitor-1"), default);
        await repository.CreateAsync(
            new Sitting(Guid.NewGuid(), TestFormat.Quick, ["l1", "s1"], now.AddHours(-1), now, "visitor-1"), default);
        await repository.CreateAsync(
            new Sitting(Guid.NewGuid(), TestFormat.Quick, ["n2", "v2"], now, now, "visitor-2"), default);

        // Only the most recent sitting for that visitor.
        Assert.Equal(["l1", "s1"], (await repository.RecentItemIdsAsync("visitor-1", default)).Order());
        Assert.Equal(["n2", "v2"], (await repository.RecentItemIdsAsync("visitor-2", default)).Order());
        Assert.Empty(await repository.RecentItemIdsAsync("nobody", default));
        Assert.Empty(await repository.RecentItemIdsAsync(null, default));
    }
}
