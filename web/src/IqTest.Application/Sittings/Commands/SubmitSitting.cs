using IqTest.Application.Abstractions;
using IqTest.Application.Common;
using IqTest.Domain.Attempts;
using IqTest.Domain.Common;
using IqTest.Domain.Questions;
using IqTest.Domain.Scoring;
using MediatR;

namespace IqTest.Application.Sittings.Commands;

/// <summary>
/// Scores and files a sitting the server itself issued.
///
/// No score is accepted from the caller. The answers are looked up from the
/// sitting the server stored, scored here, and only then written down.
/// </summary>
public sealed record SubmitSittingCommand(Guid SittingId, ParticipantDetails? Participant)
    : IRequest<SubmitAttemptResult>;

/// <summary>What the caller gets back: an address, and where it landed.</summary>
public sealed record SubmitAttemptResult(
    string CertificateSlug,
    int Index,
    double Percentile,
    string Band,
    int Correct,
    int Total,
    bool IsRanked,
    int? Rank);

public sealed class SubmitSittingHandler(
    ISittingRepository sittings,
    IAttemptRepository attempts,
    IQuestionBank bank,
    ILeaderboardReadStore leaderboard,
    IClock clock,
    IIdentityGenerator ids)
    : IRequestHandler<SubmitSittingCommand, SubmitAttemptResult>
{
    public async Task<SubmitAttemptResult> Handle(SubmitSittingCommand request, CancellationToken cancellationToken)
    {
        var sitting = await sittings.FindAsync(request.SittingId, cancellationToken)
            ?? throw new DomainException("That test could not be found.");

        if (sitting.IsSubmitted)
            throw new DomainException("That test has already been submitted.");

        var now = clock.UtcNow;

        var answered = sitting.QuestionIds
            .Select((id, position) => new AnsweredQuestion(bank.Pool[id], sitting.Answers[position]))
            .ToList();

        var attempt = AttemptFactory.Complete(
            ids,
            request.Participant,
            sitting.Format,
            TestPlatform.Web,
            answered,
            sitting.Elapsed(now),
            now);

        await attempts.AddAsync(attempt, cancellationToken);
        await sittings.MarkSubmittedAsync(sitting.Id, now, cancellationToken);

        var rank = attempt.IsRanked
            ? await leaderboard.GetRankAsync(attempt.Id, cancellationToken)
            : null;

        return AttemptFactory.Describe(attempt, rank);
    }
}

/// <summary>Shared between the two submission paths so they cannot drift.</summary>
internal static class AttemptFactory
{
    public static Attempt Complete(
        IIdentityGenerator ids,
        ParticipantDetails? details,
        TestFormat format,
        TestPlatform platform,
        IReadOnlyList<AnsweredQuestion> answers,
        TimeSpan duration,
        DateTimeOffset now)
    {
        var participant = details is null
            ? null
            : Participant.Create(ids.NewId(), details.DisplayName, details.CountryCode, details.Email, now);

        return Attempt.Complete(
            ids.NewId(),
            CertificateSlug.FromGuid(ids.NewId()),
            participant,
            format,
            platform,
            answers,
            duration,
            now);
    }

    public static SubmitAttemptResult Describe(Attempt attempt, int? rank) => new(
        attempt.Slug.Value,
        attempt.Score.Index,
        attempt.Score.Percentile,
        attempt.Score.Band,
        attempt.Score.Correct,
        attempt.Score.Total,
        attempt.IsRanked,
        rank);
}
