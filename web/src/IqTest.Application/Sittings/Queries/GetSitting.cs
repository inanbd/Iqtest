using IqTest.Application.Abstractions;
using IqTest.Application.Common;
using IqTest.Domain.Common;
using IqTest.Domain.Questions;
using MediatR;

namespace IqTest.Application.Sittings.Queries;

/// <summary>Reads an in-progress sitting for display. Never exposes the key.</summary>
public sealed record GetSittingQuery(Guid SittingId) : IRequest<SittingView>;

public sealed record SittingView(
    Guid SittingId,
    TestFormat Format,
    IReadOnlyList<QuestionView> Questions,
    IReadOnlyList<int?> Answers,
    TimeSpan Remaining,
    bool IsSubmitted,
    bool HasExpired)
{
    public int AnsweredCount => Answers.Count(a => a is not null);
    public int QuestionCount => Questions.Count;
    public bool IsComplete => AnsweredCount == QuestionCount;
}

public sealed class GetSittingHandler(ISittingRepository sittings, IQuestionBank bank, IClock clock)
    : IRequestHandler<GetSittingQuery, SittingView>
{
    public async Task<SittingView> Handle(GetSittingQuery request, CancellationToken cancellationToken)
    {
        var sitting = await sittings.FindAsync(request.SittingId, cancellationToken)
            ?? throw new DomainException("That test could not be found.");

        var now = clock.UtcNow;
        return new SittingView(
            sitting.Id,
            sitting.Format,
            sitting.QuestionIds.Select(id => QuestionView.From(bank.Pool[id])).ToList(),
            sitting.Answers.ToList(),
            sitting.Remaining(now),
            sitting.IsSubmitted,
            sitting.HasExpired(now));
    }
}
