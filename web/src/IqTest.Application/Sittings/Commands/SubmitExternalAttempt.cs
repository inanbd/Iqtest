using IqTest.Application.Abstractions;
using IqTest.Application.Common;
using IqTest.Domain.Attempts;
using IqTest.Domain.Questions;
using IqTest.Domain.Scoring;
using MediatR;

namespace IqTest.Application.Sittings.Commands;

/// <summary>One answered item as reported by a client that drew its own sitting.</summary>
public sealed record SubmittedAnswer(string QuestionId, int? SelectedIndex);

/// <summary>
/// Scores and files a sitting a client drew for itself — the mobile app, which
/// works offline and so cannot be issued its items by the server.
///
/// The caller sends the items it used and what it answered, never a score.
/// The item set is checked against the blueprint first, so a submission of
/// thirty-two easy items cannot be passed off as a full test, and the answers
/// are then scored here against the server's own copy of the bank.
/// </summary>
public sealed record SubmitExternalAttemptCommand(
    TestFormat Format,
    IReadOnlyList<SubmittedAnswer> Answers,
    TimeSpan Duration,
    ParticipantDetails? Participant)
    : IRequest<SubmitAttemptResult>;

public sealed class SubmitExternalAttemptHandler(
    IAttemptRepository attempts,
    IQuestionBank bank,
    ILeaderboardReadStore leaderboard,
    IClock clock,
    IIdentityGenerator ids)
    : IRequestHandler<SubmitExternalAttemptCommand, SubmitAttemptResult>
{
    /// <summary>Guards against a wildly wrong or hostile duration.</summary>
    private static readonly TimeSpan MaxReportedDuration = TimeSpan.FromHours(6);

    public async Task<SubmitAttemptResult> Handle(SubmitExternalAttemptCommand request, CancellationToken cancellationToken)
    {
        var blueprint = TestBlueprint.For(request.Format);

        // Throws InvalidSubmissionException if this is not a sitting the pool
        // could have issued.
        var questions = bank.Pool.ValidateSitting(
            request.Answers.Select(a => a.QuestionId).ToList(),
            blueprint);

        var answered = questions
            .Zip(request.Answers, (question, answer) => new AnsweredQuestion(question, Sanitise(question, answer.SelectedIndex)))
            .ToList();

        var now = clock.UtcNow;
        var duration = request.Duration < TimeSpan.Zero || request.Duration > MaxReportedDuration
            ? blueprint.TimeLimit
            : request.Duration;

        var attempt = AttemptFactory.Complete(
            ids,
            request.Participant,
            request.Format,
            TestPlatform.Mobile,
            answered,
            duration,
            now);

        await attempts.AddAsync(attempt, cancellationToken);

        var rank = attempt.IsRanked
            ? await leaderboard.GetRankAsync(attempt.Id, cancellationToken)
            : null;

        return AttemptFactory.Describe(attempt, rank);
    }

    /// <summary>An out-of-range option counts as unanswered rather than as an error.</summary>
    private static int? Sanitise(Question question, int? selectedIndex) =>
        selectedIndex is { } index && index >= 0 && index < question.OptionCount ? index : null;
}
