using IqTest.Application.Certificates.Queries;
using IqTest.Application.Common;
using MediatR;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IqTest.Web.Pages;

/// <summary>
/// The mark-up of a finished sitting. Keyed by the sitting rather than the
/// certificate, so passing a certificate link around does not hand out the
/// answer key.
/// </summary>
public sealed class ReviewModel(ISender sender) : PageModel
{
    public IReadOnlyList<ReviewedQuestionView> Questions { get; private set; } = [];
    public Guid SittingId { get; private set; }

    public int Missed => Questions.Count(q => !q.IsCorrect);

    public async Task OnGetAsync(Guid sittingId, CancellationToken cancellationToken)
    {
        SittingId = sittingId;
        Questions = await sender.Send(new GetSittingReviewQuery(sittingId), cancellationToken);
    }
}
