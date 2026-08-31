using IqTest.Application.Abstractions;
using IqTest.Domain.Attempts;
using MediatR;

namespace IqTest.Application.Leaderboard.Queries;

/// <summary>
/// A page of the global board. Only full sittings are ranked, so every row is
/// directly comparable with every other.
/// </summary>
/// <param name="CountryCode">Restrict to one country, or null for the world.</param>
public sealed record GetLeaderboardQuery(string? CountryCode = null, int Page = 1, int PageSize = 25)
    : IRequest<LeaderboardPage>;

public sealed record LeaderboardRow(
    int Rank,
    string DisplayName,
    string CountryCode,
    int Index,
    double Percentile,
    int Correct,
    int Total,
    TimeSpan Duration,
    TestPlatform Platform,
    string CertificateSlug,
    DateTimeOffset CompletedAtUtc);

public sealed record LeaderboardPage(
    IReadOnlyList<LeaderboardRow> Rows,
    int Page,
    int PageSize,
    int TotalRows,
    string? CountryCode)
{
    public int TotalPages => PageSize <= 0 ? 1 : Math.Max(1, (int)Math.Ceiling(TotalRows / (double)PageSize));
    public bool HasPrevious => Page > 1;
    public bool HasNext => Page < TotalPages;
}

public sealed record LeaderboardStats(int RankedAttempts, int Countries, int? TopIndex, double AverageIndex);

public sealed record CountryStanding(string CountryCode, int Entries, int BestIndex, double AverageIndex);

public sealed class GetLeaderboardHandler(ILeaderboardReadStore store)
    : IRequestHandler<GetLeaderboardQuery, LeaderboardPage>
{
    private const int MaxPageSize = 100;

    public Task<LeaderboardPage> Handle(GetLeaderboardQuery request, CancellationToken cancellationToken)
    {
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, MaxPageSize);
        var country = string.IsNullOrWhiteSpace(request.CountryCode)
            ? null
            : request.CountryCode.Trim().ToUpperInvariant();

        return store.GetPageAsync(country, page, pageSize, cancellationToken);
    }
}

public sealed record GetLeaderboardStatsQuery : IRequest<LeaderboardStats>;

public sealed class GetLeaderboardStatsHandler(ILeaderboardReadStore store)
    : IRequestHandler<GetLeaderboardStatsQuery, LeaderboardStats>
{
    public Task<LeaderboardStats> Handle(GetLeaderboardStatsQuery request, CancellationToken cancellationToken)
        => store.GetStatsAsync(cancellationToken);
}

public sealed record GetCountryStandingsQuery(int Limit = 20) : IRequest<IReadOnlyList<CountryStanding>>;

public sealed class GetCountryStandingsHandler(ILeaderboardReadStore store)
    : IRequestHandler<GetCountryStandingsQuery, IReadOnlyList<CountryStanding>>
{
    public Task<IReadOnlyList<CountryStanding>> Handle(GetCountryStandingsQuery request, CancellationToken cancellationToken)
        => store.GetCountryStandingsAsync(Math.Clamp(request.Limit, 1, 250), cancellationToken);
}
