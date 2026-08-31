using IqTest.Application.Abstractions;
using IqTest.Application.Certificates.Queries;
using IqTest.Application.Leaderboard.Queries;
using IqTest.Domain.Attempts;
using IqTest.Domain.Questions;

namespace IqTest.Application.Tests;

/// <summary>
/// In-memory stand-ins for the ports. Handlers are tested against these, so
/// the tests say something about the handlers rather than about SQL — the SQL
/// has its own tests against a real server.
/// </summary>
public sealed class FakeSittingRepository : ISittingRepository
{
    private readonly Dictionary<Guid, Sitting> _sittings = [];
    private readonly Dictionary<string, List<string>> _byVisitor = [];

    public IReadOnlyDictionary<Guid, Sitting> All => _sittings;

    public Task CreateAsync(Sitting sitting, CancellationToken cancellationToken)
    {
        _sittings[sitting.Id] = sitting;
        if (sitting.VisitorKey is { } key) _byVisitor[key] = [.. sitting.QuestionIds];
        return Task.CompletedTask;
    }

    public Task<Sitting?> FindAsync(Guid sittingId, CancellationToken cancellationToken)
        => Task.FromResult(_sittings.GetValueOrDefault(sittingId));

    public Task SaveAnswerAsync(Guid sittingId, int position, int? selectedIndex, CancellationToken cancellationToken)
    {
        _sittings[sittingId].Answers[position] = selectedIndex;
        return Task.CompletedTask;
    }

    public Task MarkSubmittedAsync(Guid sittingId, DateTimeOffset submittedAtUtc, CancellationToken cancellationToken)
    {
        _sittings[sittingId].SubmittedAtUtc = submittedAtUtc;
        return Task.CompletedTask;
    }

    public Task<IReadOnlySet<string>> RecentItemIdsAsync(string? visitorKey, CancellationToken cancellationToken)
    {
        var ids = visitorKey is not null && _byVisitor.TryGetValue(visitorKey, out var seen)
            ? seen.ToHashSet()
            : [];
        return Task.FromResult<IReadOnlySet<string>>(ids);
    }
}

public sealed class FakeAttemptRepository : IAttemptRepository
{
    public List<Attempt> Saved { get; } = [];

    public Task AddAsync(Attempt attempt, CancellationToken cancellationToken)
    {
        Saved.Add(attempt);
        return Task.CompletedTask;
    }
}

public sealed class FakeLeaderboard : ILeaderboardReadStore
{
    public int? NextRank { get; set; } = 7;
    public List<Guid> RankRequests { get; } = [];

    public Task<LeaderboardPage> GetPageAsync(string? countryCode, int page, int pageSize, CancellationToken cancellationToken)
        => Task.FromResult(new LeaderboardPage([], page, pageSize, 0, countryCode));

    public Task<LeaderboardStats> GetStatsAsync(CancellationToken cancellationToken)
        => Task.FromResult(new LeaderboardStats(0, 0, null, 0));

    public Task<IReadOnlyList<CountryStanding>> GetCountryStandingsAsync(int limit, CancellationToken cancellationToken)
        => Task.FromResult<IReadOnlyList<CountryStanding>>([]);

    public Task<int?> GetRankAsync(Guid attemptId, CancellationToken cancellationToken)
    {
        RankRequests.Add(attemptId);
        return Task.FromResult(NextRank);
    }
}

public sealed class FakeCertificates : ICertificateReadStore
{
    public CertificateView? Next { get; set; }

    public Task<CertificateView?> FindAsync(string slug, CancellationToken cancellationToken)
        => Task.FromResult(Next);
}

public sealed class FixedClock(DateTimeOffset now) : IClock
{
    public DateTimeOffset UtcNow { get; set; } = now;
}

/// <summary>Hands out predictable ids so assertions can name them.</summary>
public sealed class SequentialIds : IIdentityGenerator
{
    private int _next;

    public Guid NewId() => new(++_next, 0, 0, [0, 0, 0, 0, 0, 0, 0, 0]);
}

public sealed class FakeQuestionBank(QuestionPool pool) : IQuestionBank
{
    public QuestionPool Pool { get; } = pool;

    /// <summary>A pool shaped like the real one: twice what a blueprint draws.</summary>
    public static FakeQuestionBank Standard(int perCell = 4)
    {
        var questions = new List<Question>();
        foreach (var category in Enum.GetValues<QuestionCategory>())
        {
            for (var difficulty = 1; difficulty <= 5; difficulty++)
            {
                for (var i = 0; i < perCell; i++)
                {
                    questions.Add(new TextQuestion(
                        $"{category}-{difficulty}-{i}", category, difficulty,
                        $"Prompt {category} {difficulty} {i}", ["a", "b", "c", "d"], 0, "because"));
                }
            }
        }
        return new FakeQuestionBank(new QuestionPool(questions));
    }
}
