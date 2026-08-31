using IqTest.Application.Certificates.Queries;
using IqTest.Application.Reference;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IqTest.Web.Pages;

/// <summary>
/// The certificate, at its own permanent address.
///
/// The address is an unguessable 22-character id, so it is shareable without
/// exposing anyone else's. It is public by design: that is what makes it worth
/// sharing.
/// </summary>
public sealed class CertificateModel(ISender sender) : PageModel
{
    public CertificateView Certificate { get; private set; } = null!;

    /// <summary>Present only for the person who just finished, so only they see the review link.</summary>
    public Guid? SittingId { get; private set; }

    public string ShareUrl => $"{Request.Scheme}://{Request.Host}{Request.PathBase}/certificate/{Certificate.Slug}";

    public string CountryName => Countries.NameOf(Certificate.CountryCode);
    public string CountryFlag => Countries.FlagOf(Certificate.CountryCode);

    public async Task<IActionResult> OnGetAsync(string slug, Guid? sittingId, CancellationToken cancellationToken)
    {
        var certificate = await sender.Send(new GetCertificateQuery(slug), cancellationToken);
        if (certificate is null) return NotFound();

        Certificate = certificate;
        SittingId = sittingId;
        return Page();
    }
}
