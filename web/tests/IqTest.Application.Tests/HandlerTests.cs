using IqTest.Application.Certificates.Queries;
using IqTest.Application.Common;
using IqTest.Application.Sittings.Commands;
using IqTest.Application.Sittings.Queries;
using IqTest.Domain.Attempts;
using IqTest.Domain.Common;
using IqTest.Domain.Questions;

namespace IqTest.Application.Tests;

public sealed class SittingHandlerTests
{
    private static readonly DateTimeOffset Now = new(2026, 4, 1, 12, 0, 0, TimeSpan.Zero);

    private readonly FakeQuestionBank _bank = FakeQuestionBank.Standard();
    private readonly FakeSittingRepository _sittings = new();
    private readonly FakeAttemptRepository _attempts = new();
    private readonly FakeLeaderboard _leaderboard = new();
    private readonly FixedClock _clock = new(Now);
    private readonly SequentialIds _ids = new();

    private StartSittingHandler Starter => new(_bank, _sittings, _clock, _ids);
    private SubmitSittingHandler Submitter => new(_sittings, _attempts, _bank, _leaderboard, _clock, _ids);

    private async Task<Guid> StartAsync(TestFormat format = TestFormat.Full, string? visitor = "v1")
        => (await Starter.Handle(new StartSittingCommand(format, visitor), default)).SittingId;

    [Fact]
    public async Task Starting_issues_a_sitting_matching_the_blueprint()
    {
        var result = await Starter.Handle(new StartSittingCommand(TestFormat.Full, "v1"), default);

        Assert.Equal(32, result.QuestionCount);
        Assert.Equal(TimeSpan.FromMinutes(25), result.TimeLimit);

        var sitting = _sittings.All[result.SittingId];
        Assert.Equal(32, sitting.QuestionIds.Count);
        Assert.Equal(32, sitting.QuestionIds.Distinct().Count());
        // The clock gets a little slack past the limit so a submission landing
        // right on the deadline is still accepted.
        Assert.True(sitting.ExpiresAtUtc > Now.AddMinutes(25));
    }

    [Fact]
    public async Task A_returning_visitor_gets_none_of_the_items_they_last_saw()
    {
        var first = await StartAsync();
        var second = await StartAsync();

        Assert.Empty(_sittings.All[second].QuestionIds.Intersect(_sittings.All[first].QuestionIds));
    }

    [Fact]
    public async Task Answering_records_against_the_right_position()
    {
        var id = await StartAsync();
        var handler = new AnswerQuestionHandler(_sittings, _bank, _clock);

        await handler.Handle(new AnswerQuestionCommand(id, 3, 2), default);

        Assert.Equal(2, _sittings.All[id].Answers[3]);
        Assert.Null(_sittings.All[id].Answers[0]);
    }

    [Fact]
    public async Task Answering_refuses_an_option_the_question_does_not_have()
    {
        var id = await StartAsync();
        var handler = new AnswerQuestionHandler(_sittings, _bank, _clock);

        await Assert.ThrowsAsync<DomainException>(
            () => handler.Handle(new AnswerQuestionCommand(id, 0, 9), default));
    }

    [Fact]
    public async Task Answering_refuses_once_the_clock_has_run_out()
    {
        var id = await StartAsync();
        _clock.UtcNow = Now.AddHours(2);
        var handler = new AnswerQuestionHandler(_sittings, _bank, _clock);

        await Assert.ThrowsAsync<DomainException>(
            () => handler.Handle(new AnswerQuestionCommand(id, 0, 1), default));
    }

    [Fact]
    public async Task Submitting_scores_the_answers_the_server_stored()
    {
        var id = await StartAsync();
        var sitting = _sittings.All[id];

        // Answer the first ten correctly; option 0 is the key throughout.
        for (var i = 0; i < 10; i++) sitting.Answers[i] = 0;

        _clock.UtcNow = Now.AddMinutes(12);
        var result = await Submitter.Handle(
            new SubmitSittingCommand(id, new ParticipantDetails("Ada", "GB", null)), default);

        var attempt = Assert.Single(_attempts.Saved);
        Assert.Equal(10, attempt.Score.Correct);
        Assert.Equal(32, attempt.Score.Total);
        Assert.Equal(108, attempt.Score.MaxWeightedPoints);
        Assert.Equal(TimeSpan.FromMinutes(12), attempt.Duration);
        Assert.Equal(TestPlatform.Web, attempt.Platform);
        Assert.Equal("Ada", attempt.Participant!.DisplayName);

        Assert.Equal(attempt.Score.Index, result.Index);
        Assert.True(result.IsRanked);
        Assert.Equal(7, result.Rank);
        Assert.Equal(22, result.CertificateSlug.Length);
    }

    [Fact]
    public async Task Submitting_marks_the_sitting_so_it_cannot_be_submitted_twice()
    {
        var id = await StartAsync();
        await Submitter.Handle(new SubmitSittingCommand(id, null), default);

        Assert.NotNull(_sittings.All[id].SubmittedAtUtc);
        await Assert.ThrowsAsync<DomainException>(
            () => Submitter.Handle(new SubmitSittingCommand(id, null), default));
        Assert.Single(_attempts.Saved);
    }

    [Fact]
    public async Task An_anonymous_submission_is_filed_but_never_ranked()
    {
        var id = await StartAsync();
        var result = await Submitter.Handle(new SubmitSittingCommand(id, null), default);

        Assert.Null(_attempts.Saved.Single().Participant);
        Assert.False(result.IsRanked);
        Assert.Null(result.Rank);
        // No point asking the board where an unranked attempt sits.
        Assert.Empty(_leaderboard.RankRequests);
        Assert.NotEmpty(result.CertificateSlug);
    }

    [Fact]
    public async Task The_short_form_is_scored_and_certificated_but_not_ranked()
    {
        var id = await StartAsync(TestFormat.Quick);
        var result = await Submitter.Handle(
            new SubmitSittingCommand(id, new ParticipantDetails("Ada", "GB", null)), default);

        var attempt = _attempts.Saved.Single();
        Assert.Equal(16, attempt.Score.Total);
        Assert.Equal(56, attempt.Score.MaxWeightedPoints);
        Assert.False(attempt.IsRanked);
        Assert.False(result.IsRanked);
        Assert.NotEmpty(result.CertificateSlug);
    }

    [Fact]
    public async Task Submitting_an_unknown_sitting_is_refused()
        => await Assert.ThrowsAsync<DomainException>(
            () => Submitter.Handle(new SubmitSittingCommand(Guid.NewGuid(), null), default));

    [Fact]
    public async Task Reading_a_sitting_never_exposes_the_key()
    {
        var id = await StartAsync();
        var view = await new GetSittingHandler(_sittings, _bank, _clock)
            .Handle(new GetSittingQuery(id), default);

        Assert.Equal(32, view.QuestionCount);
        Assert.All(view.Questions, q => Assert.Equal(4, q.OptionCount));
        // QuestionView carries no CorrectIndex and no Explanation at all.
        Assert.DoesNotContain(
            typeof(QuestionView).GetProperties().Select(p => p.Name),
            name => name is "CorrectIndex" or "Explanation");
    }

    [Fact]
    public async Task A_review_is_empty_until_the_sitting_has_been_submitted()
    {
        var id = await StartAsync();
        var handler = new GetSittingReviewHandler(_sittings, _bank);

        Assert.Empty(await handler.Handle(new GetSittingReviewQuery(id), default));

        await Submitter.Handle(new SubmitSittingCommand(id, null), default);

        var review = await handler.Handle(new GetSittingReviewQuery(id), default);
        Assert.Equal(32, review.Count);
        Assert.All(review, item => Assert.NotEmpty(item.Explanation));
    }
}

public sealed class ExternalSubmissionTests
{
    private static readonly DateTimeOffset Now = new(2026, 4, 1, 12, 0, 0, TimeSpan.Zero);

    private readonly FakeQuestionBank _bank = FakeQuestionBank.Standard();
    private readonly FakeAttemptRepository _attempts = new();
    private readonly FakeLeaderboard _leaderboard = new();

    private SubmitExternalAttemptHandler Handler => new(
        _attempts, _bank, _leaderboard, new FixedClock(Now), new SequentialIds());

    private List<SubmittedAnswer> GenuineSitting(TestFormat format = TestFormat.Full, bool allCorrect = true)
        => _bank.Pool
            .Draw(TestBlueprint.For(format), random: new Random(1))
            .Select(q => new SubmittedAnswer(q.Id, allCorrect ? q.CorrectIndex : 1))
            .ToList();

    [Fact]
    public async Task Scores_a_genuine_client_drawn_sitting()
    {
        var result = await Handler.Handle(new SubmitExternalAttemptCommand(
            TestFormat.Full, GenuineSitting(), TimeSpan.FromMinutes(14),
            new ParticipantDetails("Ada", "GB", null)), default);

        var attempt = Assert.Single(_attempts.Saved);
        Assert.Equal(TestPlatform.Mobile, attempt.Platform);
        Assert.Equal(32, attempt.Score.Correct);
        Assert.Equal(136, result.Index);
        Assert.True(result.IsRanked);
    }

    [Fact]
    public async Task Refuses_a_sitting_with_a_repeated_item()
    {
        var answers = GenuineSitting();
        answers[31] = answers[0];

        await Assert.ThrowsAsync<InvalidSubmissionException>(
            () => Handler.Handle(new SubmitExternalAttemptCommand(
                TestFormat.Full, answers, TimeSpan.FromMinutes(14), null), default));
        Assert.Empty(_attempts.Saved);
    }

    [Fact]
    public async Task Refuses_a_sitting_skewed_towards_the_easy_end()
    {
        var answers = new List<SubmittedAnswer>();
        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            answers.AddRange(_bank.Pool.Cell(category, 1).Take(4).Select(q => new SubmittedAnswer(q.Id, q.CorrectIndex)));
            answers.AddRange(_bank.Pool.Cell(category, 2).Take(4).Select(q => new SubmittedAnswer(q.Id, q.CorrectIndex)));
        }

        var exception = await Assert.ThrowsAsync<InvalidSubmissionException>(
            () => Handler.Handle(new SubmitExternalAttemptCommand(
                TestFormat.Full, answers, TimeSpan.FromMinutes(14),
                new ParticipantDetails("Cheat", "US", null)), default));

        Assert.Contains("difficulty", exception.Message);
        Assert.Empty(_attempts.Saved);
    }

    [Fact]
    public async Task Refuses_a_short_form_passed_off_as_a_full_sitting()
    {
        await Assert.ThrowsAsync<InvalidSubmissionException>(
            () => Handler.Handle(new SubmitExternalAttemptCommand(
                TestFormat.Full, GenuineSitting(TestFormat.Quick), TimeSpan.FromMinutes(5), null), default));
    }

    [Fact]
    public async Task Treats_an_out_of_range_option_as_unanswered_rather_than_failing()
    {
        var answers = GenuineSitting(allCorrect: false);
        answers[0] = new SubmittedAnswer(answers[0].QuestionId, 99);

        var result = await Handler.Handle(new SubmitExternalAttemptCommand(
            TestFormat.Full, answers, TimeSpan.FromMinutes(14), null), default);

        Assert.Equal(0, result.Correct);
    }

    [Theory]
    [InlineData(-500)]
    [InlineData(60 * 60 * 24)]
    public async Task Replaces_an_impossible_duration_with_the_time_limit(int seconds)
    {
        await Handler.Handle(new SubmitExternalAttemptCommand(
            TestFormat.Full, GenuineSitting(), TimeSpan.FromSeconds(seconds), null), default);

        Assert.Equal(TestBlueprint.Full.TimeLimit, _attempts.Saved.Single().Duration);
    }
}
