using IqTest.Application.Leaderboard.Queries;
using IqTest.Application.Sittings.Commands;
using IqTest.Domain.Questions;
using IqTest.Web.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IqTest.Web.Pages;

public sealed class IndexModel(ISender sender) : PageModel
{
    public LeaderboardStats Stats { get; private set; } = new(0, 0, null, 0);

    public IReadOnlyList<TestOption> Formats { get; } =
    [
        new(TestFormat.Full, "Full assessment", "A fresh draw spanning every difficulty, easiest to hardest. The only format that is ranked.", true),
        new(TestFormat.Quick, "Quick assessment", "A balanced short form — one item per difficulty, from each of the four domains. Practice only.", false),
    ];

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        Stats = await sender.Send(new GetLeaderboardStatsQuery(), cancellationToken);
    }

    public async Task<IActionResult> OnPostAsync(TestFormat format, CancellationToken cancellationToken)
    {
        // The server draws and remembers the items, so the submission can be
        // scored against what was actually presented.
        var result = await sender.Send(
            new StartSittingCommand(format, VisitorKey.GetOrCreate(HttpContext)),
            cancellationToken);

        return RedirectToPage("/Take", new { sittingId = result.SittingId, position = 0 });
    }

    public sealed record TestOption(TestFormat Format, string Title, string Blurb, bool Primary)
    {
        public TestBlueprint Blueprint => TestBlueprint.For(Format);
    }
}
