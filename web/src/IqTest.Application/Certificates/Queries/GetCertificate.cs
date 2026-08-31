using IqTest.Application.Abstractions;
using IqTest.Application.Common;
using IqTest.Domain.Attempts;
using IqTest.Domain.Questions;
using MediatR;

namespace IqTest.Application.Certificates.Queries;

/// <summary>Reads a certificate by its public address.</summary>
public sealed record GetCertificateQuery(string Slug) : IRequest<CertificateView?>;

/// <summary>
/// What a certificate page shows. Flat by design — this comes straight out of
/// SQL rather than through the domain entities.
/// </summary>
public sealed record CertificateView(
    Guid AttemptId,
    string Slug,
    string? DisplayName,
    string? CountryCode,
    TestFormat Format,
    TestPlatform Platform,
    int Index,
    double Percentile,
    string Band,
    int Correct,
    int Total,
    int WeightedPoints,
    int MaxWeightedPoints,
    TimeSpan Duration,
    DateTimeOffset CompletedAtUtc,
    bool IsRanked,
    int? Rank,
    IReadOnlyList<CategoryScoreView> ByCategory)
{
    public bool IsAnonymous => DisplayName is null;
}

public sealed class GetCertificateHandler(ICertificateReadStore store, ILeaderboardReadStore leaderboard)
    : IRequestHandler<GetCertificateQuery, CertificateView?>
{
    public async Task<CertificateView?> Handle(GetCertificateQuery request, CancellationToken cancellationToken)
    {
        if (!CertificateSlug.TryParse(request.Slug, out var slug)) return null;

        var certificate = await store.FindAsync(slug.Value, cancellationToken);
        if (certificate is null) return null;

        // Rank is live rather than stored: it moves as other people take the test.
        var rank = certificate.IsRanked
            ? await leaderboard.GetRankAsync(certificate.AttemptId, cancellationToken)
            : null;

        return certificate with { Rank = rank };
    }
}
