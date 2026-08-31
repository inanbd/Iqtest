using Dapper;
using IqTest.Application.Abstractions;
using IqTest.Application.Certificates.Queries;
using IqTest.Application.Common;
using IqTest.Application.Leaderboard.Queries;
using IqTest.Domain.Attempts;
using IqTest.Domain.Questions;
using IqTest.Domain.Scoring;

namespace IqTest.Infrastructure.Persistence;

/// <summary>
/// The read side of the board. These go straight from SQL to view models
/// without rehydrating domain entities, which is the point of separating the
/// two halves.
/// </summary>
public sealed class LeaderboardReadStore(ISqlConnectionFactory connections)
    : ILeaderboardReadStore, ICertificateReadStore
{
    /// <summary>
    /// One row per entry, ordered best first.
    ///
    /// Two rules are worth spelling out. Only ranked attempts appear, which
    /// means full sittings by a named participant. And where an email address
    /// was given, only that person's best attempt is kept, so one enthusiast
    /// cannot fill the table — attempts with no email each stand alone, since
    /// there is nothing to group them by.
    /// </summary>
    private const string RankedEntries =
        """
        WITH Entries AS (
            SELECT
                a.Id, a.CertificateSlug, a.ScoreIndex, a.Percentile, a.CorrectCount, a.TotalCount,
                a.DurationSeconds, a.Platform, a.CompletedAtUtc,
                p.DisplayName, p.CountryCode,
                ROW_NUMBER() OVER (
                    PARTITION BY CASE WHEN p.Email IS NULL THEN CONVERT(NVARCHAR(260), a.Id) ELSE LOWER(p.Email) END
                    ORDER BY a.ScoreIndex DESC, a.WeightedPoints DESC, a.DurationSeconds ASC, a.CompletedAtUtc ASC
                ) AS PersonalRank
            FROM dbo.Attempts a
            INNER JOIN dbo.Participants p ON p.Id = a.ParticipantId
            WHERE a.IsRanked = 1
        ),
        Best AS (
            SELECT *,
                ROW_NUMBER() OVER (
                    ORDER BY ScoreIndex DESC, DurationSeconds ASC, CompletedAtUtc ASC
                ) AS GlobalRank
            FROM Entries
            WHERE PersonalRank = 1
        )
        """;

    public async Task<LeaderboardPage> GetPageAsync(
        string? countryCode,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();

        // Rank is always global, so filtering by country shows where those
        // entries sit on the world board rather than renumbering them from 1.
        var sql =
            $"""
             {RankedEntries}
             SELECT COUNT(*) FROM Best WHERE (@countryCode IS NULL OR CountryCode = @countryCode);

             {RankedEntries}
             SELECT CAST(GlobalRank AS INT) AS Rank, DisplayName, CountryCode, ScoreIndex AS [Index], Percentile,
                    CorrectCount AS Correct, TotalCount AS Total, DurationSeconds, Platform,
                    CertificateSlug, CompletedAtUtc
             FROM Best
             WHERE (@countryCode IS NULL OR CountryCode = @countryCode)
             ORDER BY GlobalRank
             OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
             """;

        await using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            sql,
            new { countryCode, offset = (page - 1) * pageSize, pageSize },
            cancellationToken: cancellationToken));

        var total = await reader.ReadSingleAsync<int>();
        var rows = (await reader.ReadAsync<LeaderboardRowRow>())
            .Select(r => new LeaderboardRow(
                r.Rank, r.DisplayName, r.CountryCode, r.Index, (double)r.Percentile, r.Correct, r.Total,
                TimeSpan.FromSeconds(r.DurationSeconds), (TestPlatform)r.Platform, r.CertificateSlug,
                r.CompletedAtUtc))
            .ToList();

        return new LeaderboardPage(rows, page, pageSize, total, countryCode);
    }

    public async Task<int?> GetRankAsync(Guid attemptId, CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();
        return await connection.QuerySingleOrDefaultAsync<int?>(new CommandDefinition(
            $"""
             {RankedEntries}
             SELECT CAST(GlobalRank AS INT) FROM Best WHERE Id = @attemptId;
             """,
            new { attemptId }, cancellationToken: cancellationToken));
    }

    public async Task<LeaderboardStats> GetStatsAsync(CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();
        var row = await connection.QuerySingleAsync<StatsRow>(new CommandDefinition(
            $"""
             {RankedEntries}
             SELECT COUNT(*) AS RankedAttempts,
                    COUNT(DISTINCT CountryCode) AS Countries,
                    MAX(ScoreIndex) AS TopIndex,
                    AVG(CAST(ScoreIndex AS FLOAT)) AS AverageIndex
             FROM Best;
             """,
            cancellationToken: cancellationToken));

        return new LeaderboardStats(row.RankedAttempts, row.Countries, row.TopIndex, row.AverageIndex ?? 0);
    }

    public async Task<IReadOnlyList<CountryStanding>> GetCountryStandingsAsync(int limit, CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();
        var rows = await connection.QueryAsync<CountryStanding>(new CommandDefinition(
            $"""
             {RankedEntries}
             SELECT TOP (@limit)
                    CountryCode,
                    COUNT(*) AS Entries,
                    MAX(ScoreIndex) AS BestIndex,
                    AVG(CAST(ScoreIndex AS FLOAT)) AS AverageIndex
             FROM Best
             GROUP BY CountryCode
             ORDER BY AVG(CAST(ScoreIndex AS FLOAT)) DESC, COUNT(*) DESC;
             """,
            new { limit }, cancellationToken: cancellationToken));

        return rows.ToList();
    }

    public async Task<CertificateView?> FindAsync(string slug, CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();

        await using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            """
            SELECT a.Id, a.CertificateSlug, p.DisplayName, p.CountryCode, a.Format, a.Platform,
                   a.ScoreIndex, a.Percentile, a.CorrectCount, a.TotalCount, a.WeightedPoints,
                   a.MaxWeightedPoints, a.DurationSeconds, a.CompletedAtUtc, a.IsRanked
            FROM dbo.Attempts a
            LEFT JOIN dbo.Participants p ON p.Id = a.ParticipantId
            WHERE a.CertificateSlug = @slug;

            SELECT c.Category, c.Correct, c.Total
            FROM dbo.AttemptCategoryScores c
            INNER JOIN dbo.Attempts a ON a.Id = c.AttemptId
            WHERE a.CertificateSlug = @slug
            ORDER BY c.Category;
            """,
            new { slug }, cancellationToken: cancellationToken));

        var row = await reader.ReadSingleOrDefaultAsync<CertificateRow>();
        if (row is null) return null;

        var categories = (await reader.ReadAsync<CategoryRow>())
            .Select(c => new CategoryScoreView((QuestionCategory)c.Category, c.Correct, c.Total))
            .ToList();

        return new CertificateView(
            row.Id,
            row.CertificateSlug,
            row.DisplayName,
            row.CountryCode,
            (TestFormat)row.Format,
            (TestPlatform)row.Platform,
            row.ScoreIndex,
            (double)row.Percentile,
            DeviationScale.BandFor(row.ScoreIndex),
            row.CorrectCount,
            row.TotalCount,
            row.WeightedPoints,
            row.MaxWeightedPoints,
            TimeSpan.FromSeconds(row.DurationSeconds),
            row.CompletedAtUtc,
            row.IsRanked,
            null,
            categories);
    }

    // Percentile is DECIMAL(5,2) in the schema, so it must be read as decimal.
    private sealed record LeaderboardRowRow(
        int Rank, string DisplayName, string CountryCode, int Index, decimal Percentile,
        int Correct, int Total, int DurationSeconds, byte Platform, string CertificateSlug,
        DateTimeOffset CompletedAtUtc);

    private sealed record StatsRow(int RankedAttempts, int Countries, int? TopIndex, double? AverageIndex);

    private sealed record CertificateRow(
        Guid Id, string CertificateSlug, string? DisplayName, string? CountryCode, byte Format,
        byte Platform, int ScoreIndex, decimal Percentile, int CorrectCount, int TotalCount,
        int WeightedPoints, int MaxWeightedPoints, int DurationSeconds, DateTimeOffset CompletedAtUtc,
        bool IsRanked);

    private sealed record CategoryRow(byte Category, int Correct, int Total);
}
