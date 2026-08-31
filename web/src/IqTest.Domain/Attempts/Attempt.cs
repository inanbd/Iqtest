using IqTest.Domain.Questions;
using IqTest.Domain.Scoring;

namespace IqTest.Domain.Attempts;

/// <summary>Where a submission came from.</summary>
public enum TestPlatform
{
    Web = 1,
    Mobile = 2,
}

/// <summary>One answered item, as recorded against a completed attempt.</summary>
public sealed record AttemptAnswer(string QuestionId, int? SelectedIndex, bool IsCorrect);

/// <summary>
/// A completed, scored sitting. Every attempt gets a certificate; only full
/// sittings are ranked, so a 16-item short form cannot outrank a 32-item one.
/// </summary>
public sealed class Attempt
{
    private Attempt(
        Guid id,
        CertificateSlug slug,
        Participant? participant,
        TestFormat format,
        TestPlatform platform,
        ScoreResult score,
        IReadOnlyList<AttemptAnswer> answers,
        TimeSpan duration,
        DateTimeOffset completedAtUtc)
    {
        Id = id;
        Slug = slug;
        Participant = participant;
        Format = format;
        Platform = platform;
        Score = score;
        Answers = answers;
        Duration = duration;
        CompletedAtUtc = completedAtUtc;
    }

    public Guid Id { get; }
    public CertificateSlug Slug { get; }

    /// <summary>Null when the candidate declined to be named.</summary>
    public Participant? Participant { get; }

    public TestFormat Format { get; }
    public TestPlatform Platform { get; }
    public ScoreResult Score { get; }
    public IReadOnlyList<AttemptAnswer> Answers { get; }
    public TimeSpan Duration { get; }
    public DateTimeOffset CompletedAtUtc { get; }

    /// <summary>
    /// Whether this attempt appears on the leaderboard. It must be a full
    /// sitting, and it must be attributable to someone.
    /// </summary>
    public bool IsRanked => TestBlueprint.For(Format).IsRanked && Participant is not null;

    public static Attempt Complete(
        Guid id,
        CertificateSlug slug,
        Participant? participant,
        TestFormat format,
        TestPlatform platform,
        IReadOnlyList<AnsweredQuestion> answers,
        TimeSpan duration,
        DateTimeOffset completedAtUtc)
    {
        var score = ScoreCalculator.Score(answers);
        var recorded = answers
            .Select(a => new AttemptAnswer(a.Question.Id, a.SelectedIndex, a.IsCorrect))
            .ToList();

        return new Attempt(id, slug, participant, format, platform, score, recorded, duration, completedAtUtc);
    }

    public static Attempt Rehydrate(
        Guid id,
        CertificateSlug slug,
        Participant? participant,
        TestFormat format,
        TestPlatform platform,
        ScoreResult score,
        IReadOnlyList<AttemptAnswer> answers,
        TimeSpan duration,
        DateTimeOffset completedAtUtc)
        => new(id, slug, participant, format, platform, score, answers, duration, completedAtUtc);
}
