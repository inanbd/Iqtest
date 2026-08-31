using System.ComponentModel.DataAnnotations;
using IqTest.Application.Common;
using IqTest.Application.Reference;
using IqTest.Application.Sittings.Commands;
using IqTest.Application.Sittings.Queries;
using IqTest.Domain.Common;
using IqTest.Domain.Questions;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IqTest.Web.Pages;

/// <summary>
/// Collects the little we ask for, then submits. Everything here is optional:
/// a candidate can decline and still get their score and a certificate, just
/// without a place on the board.
/// </summary>
public sealed class FinishModel(ISender sender) : PageModel
{
    public SittingView Sitting { get; private set; } = null!;
    public IReadOnlyList<Country> Countries { get; private set; } = [];
    public bool Expired { get; private set; }
    public string? Error { get; private set; }

    public TestBlueprint Blueprint => TestBlueprint.For(Sitting.Format);

    [BindProperty, StringLength(40)]
    public string? DisplayName { get; set; }

    [BindProperty]
    public string? CountryCode { get; set; }

    [BindProperty, EmailAddress, StringLength(254)]
    public string? Email { get; set; }

    public async Task<IActionResult> OnGetAsync(Guid sittingId, bool expired, CancellationToken cancellationToken)
    {
        Expired = expired;
        var redirect = await LoadAsync(sittingId, cancellationToken);
        return redirect ?? Page();
    }

    public async Task<IActionResult> OnPostAsync(Guid sittingId, bool anonymous, CancellationToken cancellationToken)
    {
        var redirect = await LoadAsync(sittingId, cancellationToken);
        if (redirect is not null) return redirect;

        ParticipantDetails? participant = null;
        if (!anonymous)
        {
            if (string.IsNullOrWhiteSpace(DisplayName) || string.IsNullOrWhiteSpace(CountryCode))
            {
                Error = "A name and a country are needed to appear on the board. Or submit without them.";
                return Page();
            }
            participant = new ParticipantDetails(DisplayName, CountryCode, Email);
        }

        try
        {
            var result = await sender.Send(new SubmitSittingCommand(sittingId, participant), cancellationToken);
            return RedirectToPage("/Certificate", new { slug = result.CertificateSlug, sittingId });
        }
        catch (DomainException exception)
        {
            Error = exception.Message;
            return Page();
        }
    }

    private async Task<IActionResult?> LoadAsync(Guid sittingId, CancellationToken cancellationToken)
    {
        Sitting = await sender.Send(new GetSittingQuery(sittingId), cancellationToken);
        Countries = await sender.Send(new GetCountriesQuery(), cancellationToken);

        // Already submitted: there is nothing to do here but show the result.
        if (Sitting.IsSubmitted) return RedirectToPage("/Index");
        return null;
    }
}
