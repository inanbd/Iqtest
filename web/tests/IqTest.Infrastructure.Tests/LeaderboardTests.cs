using IqTest.Domain.Attempts;
using IqTest.Domain.Questions;
using IqTest.Domain.Scoring;
using IqTest.Infrastructure.Persistence;

namespace IqTest.Infrastructure.Tests;

/// <summary>
/// The ranking rules live in SQL, so they are tested against SQL rather than
/// reimplemented in a fake.
/// </summary>
[Collection(SqlServerCollection.Name)]
public sealed class LeaderboardTests(SqlServerFixture sql)
{
    private void SkipIfUnavailable() =>
        Skip.IfNot(sql.IsAvailable, $"SQL Server is not reachable: {sql.UnavailableReason}");

    /// <summary>
    /// Builds a full sitting scoring exactly <paramref name="correct"/> of 8
    /// weighted points, so a test can dial a score in directly.
    /// </summary>
    private static Attempt AttemptScoring(
        string name,
        string country,
        int weightedPoints,
        string? email = null,
        TimeSpan? duration = null,
        DateTimeOffset? completedAt = null,
        TestFormat format = TestFormat.Full,
        TestPlatform platform = TestPlatform.Web)
    {
        // Eight difficulty-1 items: weighted points then equal the number right.
        var questions = Enumerable.Range(0, 8)
            .Select(i => new TextQuestion($"q{i}", QuestionCategory.Numerical, 1, "?", ["a", "b", "c", "d"], 0, "x"))
            .ToList();

        var answers = questions
            .Select((q, i) => new AnsweredQuestion(q, i < weightedPoints ? 0 : 1))
            .ToList();

        var participant = Participant.Create(Guid.NewGuid(), name, country, email, DateTimeOffset.UtcNow);

        return Attempt.Complete(
            Guid.NewGuid(), CertificateSlug.NewSlug(), participant, format, platform, answers,
            duration ?? TimeSpan.FromMinutes(10),
            completedAt ?? DateTimeOffset.UtcNow);
    }

    private async Task<LeaderboardReadStore> SeedAsync(params Attempt[] attempts)
    {
        await sql.ResetAsync();
        var repository = new AttemptRepository(sql.Connections);
        foreach (var attempt in attempts)
            await repository.AddAsync(attempt, default);
        return new LeaderboardReadStore(sql.Connections);
    }

    [SkippableFact]
    public async Task Ranks_by_score_then_by_the_faster_time()
    {
        SkipIfUnavailable();

        var store = await SeedAsync(
            AttemptScoring("Middling", "GB", 4),
            AttemptScoring("Best", "FR", 7),
            AttemptScoring("SlowTie", "DE", 7, duration: TimeSpan.FromMinutes(20)),
            AttemptScoring("Lowest", "ES", 1));

        var page = await store.GetPageAsync(null, 1, 25, default);

        // Best and SlowTie score the same; the quicker sitting takes it.
        Assert.Equal(["Best", "SlowTie", "Middling", "Lowest"], page.Rows.Select(r => r.DisplayName));
        Assert.Equal([1, 2, 3, 4], page.Rows.Select(r => r.Rank));
        Assert.Equal(4, page.TotalRows);
    }

    [SkippableFact]
    public async Task Keeps_only_the_best_attempt_of_a_participant_who_gave_an_email()
    {
        SkipIfUnavailable();

        var store = await SeedAsync(
            AttemptScoring("Keen", "GB", 3, email: "keen@example.com"),
            AttemptScoring("Keen", "GB", 7, email: "keen@example.com"),
            AttemptScoring("Keen", "GB", 5, email: "KEEN@example.com"),
            AttemptScoring("Someone", "FR", 6));

        var page = await store.GetPageAsync(null, 1, 25, default);

        // One row for Keen, at their best score, matched case-insensitively.
        Assert.Equal(2, page.TotalRows);
        var keen = Assert.Single(page.Rows, r => r.DisplayName == "Keen");
        Assert.Equal(1, keen.Rank);
        Assert.Equal(7, keen.Correct);
    }

    [SkippableFact]
    public async Task Keeps_every_attempt_when_no_email_was_given()
    {
        SkipIfUnavailable();

        // With nothing to identify them by, two anonymous-but-named entries are
        // two different people as far as the board can tell.
        var store = await SeedAsync(
            AttemptScoring("Sam", "GB", 3),
            AttemptScoring("Sam", "GB", 6));

        var page = await store.GetPageAsync(null, 1, 25, default);
        Assert.Equal(2, page.TotalRows);
    }

    [SkippableFact]
    public async Task Excludes_the_short_form_from_the_board()
    {
        SkipIfUnavailable();

        var quick = AttemptScoring("Practiser", "GB", 8, format: TestFormat.Quick);
        var full = AttemptScoring("Sitter", "GB", 2);
        var store = await SeedAsync(quick, full);

        var page = await store.GetPageAsync(null, 1, 25, default);

        // A perfect quick test does not outrank a poor full one, because it is
        // not on the board at all.
        Assert.Equal(["Sitter"], page.Rows.Select(r => r.DisplayName));
        Assert.Null(await store.GetRankAsync(quick.Id, default));
        Assert.Equal(1, await store.GetRankAsync(full.Id, default));
    }

    [SkippableFact]
    public async Task Filtering_by_country_keeps_the_global_rank()
    {
        SkipIfUnavailable();

        var store = await SeedAsync(
            AttemptScoring("Global1", "FR", 8),
            AttemptScoring("Local1", "GB", 6),
            AttemptScoring("Global2", "FR", 7),
            AttemptScoring("Local2", "GB", 2));

        var page = await store.GetPageAsync("GB", 1, 25, default);

        Assert.Equal(2, page.TotalRows);
        Assert.Equal(["Local1", "Local2"], page.Rows.Select(r => r.DisplayName));
        // Local1 is third in the world, and the filtered view says so rather
        // than renumbering them first.
        Assert.Equal([3, 4], page.Rows.Select(r => r.Rank));
    }

    [SkippableFact]
    public async Task Pages_through_the_board()
    {
        SkipIfUnavailable();

        var store = await SeedAsync(
            Enumerable.Range(0, 7).Select(i => AttemptScoring($"P{i}", "GB", 8 - i)).ToArray());

        var first = await store.GetPageAsync(null, 1, 3, default);
        var second = await store.GetPageAsync(null, 2, 3, default);
        var last = await store.GetPageAsync(null, 3, 3, default);

        Assert.Equal(7, first.TotalRows);
        Assert.Equal(3, first.TotalPages);
        Assert.Equal([1, 2, 3], first.Rows.Select(r => r.Rank));
        Assert.Equal([4, 5, 6], second.Rows.Select(r => r.Rank));
        Assert.Equal([7], last.Rows.Select(r => r.Rank));
        Assert.False(first.HasPrevious);
        Assert.True(first.HasNext);
        Assert.False(last.HasNext);
    }

    [SkippableFact]
    public async Task Reports_stats_and_country_standings()
    {
        SkipIfUnavailable();

        var store = await SeedAsync(
            AttemptScoring("A", "GB", 8),
            AttemptScoring("B", "GB", 4),
            AttemptScoring("C", "FR", 7));

        var stats = await store.GetStatsAsync(default);
        Assert.Equal(3, stats.RankedAttempts);
        Assert.Equal(2, stats.Countries);
        Assert.NotNull(stats.TopIndex);

        var standings = await store.GetCountryStandingsAsync(10, default);
        Assert.Equal(2, standings.Count);
        // Ordered by average, so France's single strong entry leads.
        Assert.Equal("FR", standings[0].CountryCode);
        Assert.Equal(1, standings[0].Entries);
        Assert.Equal(2, standings[1].Entries);
    }

    [SkippableFact]
    public async Task An_empty_board_reports_zeroes_rather_than_failing()
    {
        SkipIfUnavailable();

        var store = await SeedAsync();
        var stats = await store.GetStatsAsync(default);
        var page = await store.GetPageAsync(null, 1, 25, default);

        Assert.Equal(0, stats.RankedAttempts);
        Assert.Equal(0, stats.Countries);
        Assert.Null(stats.TopIndex);
        Assert.Equal(0, stats.AverageIndex);
        Assert.Empty(page.Rows);
        Assert.Equal(1, page.TotalPages);
    }
}
