using IqTest.Application.Abstractions;
using IqTest.Application.Common;
using MediatR;

namespace IqTest.Application.Certificates.Queries;

/// <summary>
/// The full mark-up of a finished sitting: every item with the candidate's
/// answer, the right answer and why. Keyed by the sitting rather than the
/// certificate, so a shared certificate link does not hand out the answers.
/// </summary>
public sealed record GetSittingReviewQuery(Guid SittingId) : IRequest<IReadOnlyList<ReviewedQuestionView>>;

public sealed class GetSittingReviewHandler(ISittingRepository sittings, IQuestionBank bank)
    : IRequestHandler<GetSittingReviewQuery, IReadOnlyList<ReviewedQuestionView>>
{
    public async Task<IReadOnlyList<ReviewedQuestionView>> Handle(
        GetSittingReviewQuery request,
        CancellationToken cancellationToken)
    {
        var sitting = await sittings.FindAsync(request.SittingId, cancellationToken);
        if (sitting is null || !sitting.IsSubmitted) return [];

        return sitting.QuestionIds
            .Select((id, position) => ReviewedQuestionView.From(bank.Pool[id], sitting.Answers[position]))
            .ToList();
    }
}
