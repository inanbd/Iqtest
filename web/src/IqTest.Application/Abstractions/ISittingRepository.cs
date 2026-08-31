using IqTest.Application.Sittings;
using IqTest.Domain.Questions;

namespace IqTest.Application.Abstractions;

/// <summary>
/// The write side for a test in progress: which items were issued, in what
/// order, and what has been answered so far.
/// </summary>
public interface ISittingRepository
{
    Task CreateAsync(Sitting sitting, CancellationToken cancellationToken);

    Task<Sitting?> FindAsync(Guid sittingId, CancellationToken cancellationToken);

    Task SaveAnswerAsync(Guid sittingId, int position, int? selectedIndex, CancellationToken cancellationToken);

    Task MarkSubmittedAsync(Guid sittingId, DateTimeOffset submittedAtUtc, CancellationToken cancellationToken);

    /// <summary>Item ids used by the most recent attempt from this visitor, if any.</summary>
    Task<IReadOnlySet<string>> RecentItemIdsAsync(string? visitorKey, CancellationToken cancellationToken);
}

/// <summary>A test that has been issued but not yet scored.</summary>
public sealed class Sitting
{
    public Sitting(
        Guid id,
        TestFormat format,
        IReadOnlyList<string> questionIds,
        DateTimeOffset startedAtUtc,
        DateTimeOffset expiresAtUtc,
        string? visitorKey)
    {
        Id = id;
        Format = format;
        QuestionIds = questionIds;
        StartedAtUtc = startedAtUtc;
        ExpiresAtUtc = expiresAtUtc;
        VisitorKey = visitorKey;
        Answers = new int?[questionIds.Count];
    }

    public Guid Id { get; }
    public TestFormat Format { get; }
    public IReadOnlyList<string> QuestionIds { get; }
    public DateTimeOffset StartedAtUtc { get; }
    public DateTimeOffset ExpiresAtUtc { get; }
    public DateTimeOffset? SubmittedAtUtc { get; set; }

    /// <summary>Opaque per-browser key, so a repeat visitor gets fresh items.</summary>
    public string? VisitorKey { get; }

    public int?[] Answers { get; }

    public bool IsSubmitted => SubmittedAtUtc is not null;

    public bool HasExpired(DateTimeOffset now) => now >= ExpiresAtUtc;

    public TimeSpan Remaining(DateTimeOffset now)
    {
        var left = ExpiresAtUtc - now;
        return left < TimeSpan.Zero ? TimeSpan.Zero : left;
    }

    public TimeSpan Elapsed(DateTimeOffset now)
    {
        var taken = now - StartedAtUtc;
        var limit = TestBlueprint.For(Format).TimeLimit;
        return taken > limit ? limit : taken;
    }
}
