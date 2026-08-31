using IqTest.Application.Certificates.Queries;
using IqTest.Application.Leaderboard.Queries;

namespace IqTest.Application.Abstractions;

/// <summary>
/// The read side. Deliberately separate from the write repositories: these
/// return flat view models straight from SQL rather than rehydrating domain
/// entities, which is the point of splitting the two.
/// </summary>
public interface ILeaderboardReadStore
{
    Task<LeaderboardPage> GetPageAsync(
        string? countryCode,
        int page,
        int pageSize,
        CancellationToken cancellationToken);

    Task<LeaderboardStats> GetStatsAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<CountryStanding>> GetCountryStandingsAsync(int limit, CancellationToken cancellationToken);

    /// <summary>Where a given attempt sits on the board, or null if unranked.</summary>
    Task<int?> GetRankAsync(Guid attemptId, CancellationToken cancellationToken);
}

public interface ICertificateReadStore
{
    Task<CertificateView?> FindAsync(string slug, CancellationToken cancellationToken);
}
