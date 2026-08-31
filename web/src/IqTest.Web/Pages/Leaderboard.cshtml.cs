using IqTest.Application.Leaderboard.Queries;
using IqTest.Application.Reference;
using MediatR;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IqTest.Web.Pages;

/// <summary>
/// The shared board. Both platforms write to it, so a score set on a phone and
/// one set in a browser sit on the same table.
/// </summary>
public sealed class LeaderboardModel(ISender sender) : PageModel
{
    public LeaderboardPage Board { get; private set; } = null!;
    public LeaderboardStats Stats { get; private set; } = new(0, 0, null, 0);
    public IReadOnlyList<CountryStanding> Standings { get; private set; } = [];
    public IReadOnlyList<Country> Countries { get; private set; } = [];
    public string? Country { get; private set; }

    public async Task OnGetAsync(string? country, int? page, CancellationToken cancellationToken)
    {
        Country = string.IsNullOrWhiteSpace(country) ? null : country.ToUpperInvariant();

        Board = await sender.Send(new GetLeaderboardQuery(Country, page ?? 1), cancellationToken);
        Stats = await sender.Send(new GetLeaderboardStatsQuery(), cancellationToken);
        Standings = await sender.Send(new GetCountryStandingsQuery(10), cancellationToken);
        Countries = await sender.Send(new GetCountriesQuery(), cancellationToken);
    }

    public static string NameOf(string code) => Application.Reference.Countries.NameOf(code);
    public static string FlagOf(string code) => Application.Reference.Countries.FlagOf(code);
}
