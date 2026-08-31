using IqTest.Application.Certificates.Queries;
using IqTest.Application.Common;
using IqTest.Application.Leaderboard.Queries;
using IqTest.Application.Reference;
using IqTest.Application.Sittings.Commands;
using IqTest.Domain.Questions;
using MediatR;

namespace IqTest.Web.Api;

/// <summary>
/// The JSON surface the Flutter app talks to. Every endpoint is a thin shell
/// over a MediatR request — no logic lives here.
/// </summary>
public static class ApiEndpoints
{
    public static IEndpointRouteBuilder MapApiEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api").WithTags("IQ test");

        api.MapGet("/countries", async (ISender sender, CancellationToken ct) =>
        {
            var countries = await sender.Send(new GetCountriesQuery(), ct);
            return Results.Ok(countries.Select(c => new { c.Code, c.Name, c.Flag }));
        })
        .WithSummary("The country list for the join form.");

        api.MapPost("/attempts", async (SubmitAttemptRequest request, ISender sender, CancellationToken ct) =>
        {
            // Note what is not in the request: a score. The client sends the
            // items it used and what it answered; the server scores it.
            var result = await sender.Send(new SubmitExternalAttemptCommand(
                request.ParseFormat(),
                request.Answers.Select(a => new SubmittedAnswer(a.QuestionId, a.SelectedIndex)).ToList(),
                TimeSpan.FromSeconds(Math.Max(0, request.DurationSeconds)),
                request.ToParticipant()), ct);

            return Results.Ok(SubmitAttemptResponse.From(result));
        })
        .WithSummary("Files a sitting drawn by the client, scoring it server-side.");

        api.MapGet("/leaderboard", async (
            string? country,
            int? page,
            int? pageSize,
            ISender sender,
            CancellationToken ct) =>
        {
            var result = await sender.Send(new GetLeaderboardQuery(country, page ?? 1, pageSize ?? 25), ct);
            return Results.Ok(LeaderboardResponse.From(result));
        })
        .WithSummary("A page of the global board.");

        api.MapGet("/leaderboard/stats", async (ISender sender, CancellationToken ct) =>
            Results.Ok(await sender.Send(new GetLeaderboardStatsQuery(), ct)))
        .WithSummary("Totals across the board.");

        api.MapGet("/leaderboard/countries", async (int? limit, ISender sender, CancellationToken ct) =>
        {
            var standings = await sender.Send(new GetCountryStandingsQuery(limit ?? 20), ct);
            return Results.Ok(standings.Select(s => new
            {
                s.CountryCode,
                Country = Countries.NameOf(s.CountryCode),
                s.Entries,
                s.BestIndex,
                AverageIndex = Math.Round(s.AverageIndex, 1),
            }));
        })
        .WithSummary("Countries ranked by their average.");

        api.MapGet("/certificates/{slug}", async (string slug, ISender sender, CancellationToken ct) =>
        {
            var certificate = await sender.Send(new GetCertificateQuery(slug), ct);
            return certificate is null
                ? Results.NotFound(new { error = "No certificate has that address." })
                : Results.Ok(CertificateResponse.From(certificate));
        })
        .WithSummary("Reads a certificate by its public address.");

        return app;
    }
}

/// <summary>What a client submits. Deliberately has no score field.</summary>
public sealed record SubmitAttemptRequest(
    string Format,
    IReadOnlyList<SubmitAttemptAnswer> Answers,
    int DurationSeconds,
    string? DisplayName,
    string? CountryCode,
    string? Email)
{
    public TestFormat ParseFormat() =>
        Enum.TryParse<TestFormat>(Format, ignoreCase: true, out var format)
            ? format
            : throw new IqTest.Domain.Common.DomainException($"'{Format}' is not a test format.");

    /// <summary>Null when the candidate declined to be named, which is allowed.</summary>
    public ParticipantDetails? ToParticipant() =>
        string.IsNullOrWhiteSpace(DisplayName) || string.IsNullOrWhiteSpace(CountryCode)
            ? null
            : new ParticipantDetails(DisplayName, CountryCode, Email);
}

public sealed record SubmitAttemptAnswer(string QuestionId, int? SelectedIndex);

public sealed record SubmitAttemptResponse(
    string CertificateSlug,
    string CertificateUrl,
    int Score,
    double Percentile,
    string Band,
    int Correct,
    int Total,
    bool IsRanked,
    int? Rank)
{
    public static SubmitAttemptResponse From(SubmitAttemptResult result) => new(
        result.CertificateSlug,
        $"/certificate/{result.CertificateSlug}",
        result.Index,
        Math.Round(result.Percentile, 1),
        result.Band,
        result.Correct,
        result.Total,
        result.IsRanked,
        result.Rank);
}

public sealed record LeaderboardResponse(
    IReadOnlyList<LeaderboardRowResponse> Rows,
    int Page,
    int PageSize,
    int TotalRows,
    int TotalPages,
    string? Country)
{
    public static LeaderboardResponse From(LeaderboardPage page) => new(
        page.Rows.Select(LeaderboardRowResponse.From).ToList(),
        page.Page,
        page.PageSize,
        page.TotalRows,
        page.TotalPages,
        page.CountryCode);
}

public sealed record LeaderboardRowResponse(
    int Rank,
    string DisplayName,
    string CountryCode,
    string Country,
    string Flag,
    int Score,
    double Percentile,
    int Correct,
    int Total,
    int DurationSeconds,
    string Platform,
    string CertificateSlug,
    DateTimeOffset CompletedAtUtc)
{
    public static LeaderboardRowResponse From(LeaderboardRow row) => new(
        row.Rank,
        row.DisplayName,
        row.CountryCode,
        Countries.NameOf(row.CountryCode),
        Countries.FlagOf(row.CountryCode),
        row.Index,
        Math.Round(row.Percentile, 1),
        row.Correct,
        row.Total,
        (int)row.Duration.TotalSeconds,
        row.Platform.ToString(),
        row.CertificateSlug,
        row.CompletedAtUtc);
}

public sealed record CertificateResponse(
    string Slug,
    string? DisplayName,
    string? CountryCode,
    string? Country,
    string Format,
    string Platform,
    int Score,
    double Percentile,
    string Band,
    int Correct,
    int Total,
    int DurationSeconds,
    DateTimeOffset CompletedAtUtc,
    bool IsRanked,
    int? Rank,
    IReadOnlyList<CertificateCategoryResponse> ByCategory)
{
    public static CertificateResponse From(CertificateView view) => new(
        view.Slug,
        view.DisplayName,
        view.CountryCode,
        view.CountryCode is null ? null : Countries.NameOf(view.CountryCode),
        view.Format.ToString(),
        view.Platform.ToString(),
        view.Index,
        Math.Round(view.Percentile, 1),
        view.Band,
        view.Correct,
        view.Total,
        (int)view.Duration.TotalSeconds,
        view.CompletedAtUtc,
        view.IsRanked,
        view.Rank,
        view.ByCategory
            .Select(c => new CertificateCategoryResponse(c.Category.ToString(), c.Correct, c.Total))
            .ToList());
}

public sealed record CertificateCategoryResponse(string Category, int Correct, int Total);
