using IqTest.Application.Sittings.Commands;
using IqTest.Application.Sittings.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IqTest.Web.Pages;

/// <summary>One item at a time, with the answer sheet held server-side.</summary>
public sealed class TakeModel(ISender sender) : PageModel
{
    public SittingView Sitting { get; private set; } = null!;
    public int Position { get; private set; }
    public QuestionDisplay Display { get; private set; } = null!;

    public bool IsLast => Position == Sitting.QuestionCount - 1;
    public bool IsFirst => Position == 0;
    public double ProgressPercent => Sitting.QuestionCount == 0
        ? 0
        : (Position + 1) * 100.0 / Sitting.QuestionCount;

    public async Task<IActionResult> OnGetAsync(Guid sittingId, int position, CancellationToken cancellationToken)
    {
        var redirect = await LoadAsync(sittingId, position, cancellationToken);
        return redirect ?? Page();
    }

    /// <summary>Records the answer, then moves on. Posting per answer keeps
    /// the sheet on the server, so a refresh or a new device resumes cleanly.</summary>
    public async Task<IActionResult> OnPostAnswerAsync(
        Guid sittingId,
        int position,
        int? selectedIndex,
        string? then,
        CancellationToken cancellationToken)
    {
        await sender.Send(new AnswerQuestionCommand(sittingId, position, selectedIndex), cancellationToken);

        var next = then switch
        {
            "next" => position + 1,
            "back" => position - 1,
            _ => position,
        };

        var sitting = await sender.Send(new GetSittingQuery(sittingId), cancellationToken);
        if (next >= sitting.QuestionCount) return RedirectToPage("/Finish", new { sittingId });

        return RedirectToPage(new { sittingId, position = Math.Max(0, next) });
    }

    private async Task<IActionResult?> LoadAsync(Guid sittingId, int position, CancellationToken cancellationToken)
    {
        Sitting = await sender.Send(new GetSittingQuery(sittingId), cancellationToken);

        if (Sitting.IsSubmitted) return RedirectToPage("/Finish", new { sittingId });
        // Out of time is not a dead end: the finish page submits what there is.
        if (Sitting.HasExpired) return RedirectToPage("/Finish", new { sittingId, expired = true });

        Position = Math.Clamp(position, 0, Sitting.QuestionCount - 1);
        Display = new QuestionDisplay
        {
            Question = Sitting.Questions[Position],
            SelectedIndex = Sitting.Answers[Position],
        };
        return null;
    }
}
