using IqTest.Application.Abstractions;
using IqTest.Domain.Common;
using MediatR;

namespace IqTest.Application.Sittings.Commands;

/// <summary>Records one answer against an in-progress sitting.</summary>
public sealed record AnswerQuestionCommand(Guid SittingId, int Position, int? SelectedIndex)
    : IRequest;

public sealed class AnswerQuestionHandler(
    ISittingRepository sittings,
    IQuestionBank bank,
    IClock clock)
    : IRequestHandler<AnswerQuestionCommand>
{
    public async Task Handle(AnswerQuestionCommand request, CancellationToken cancellationToken)
    {
        var sitting = await sittings.FindAsync(request.SittingId, cancellationToken)
            ?? throw new DomainException("That test could not be found.");

        if (sitting.IsSubmitted)
            throw new DomainException("That test has already been submitted.");
        if (sitting.HasExpired(clock.UtcNow))
            throw new DomainException("Time is up for that test.");
        if (request.Position < 0 || request.Position >= sitting.QuestionIds.Count)
            throw new DomainException("There is no question at that position.");

        if (request.SelectedIndex is { } selected)
        {
            var question = bank.Pool[sitting.QuestionIds[request.Position]];
            if (selected < 0 || selected >= question.OptionCount)
                throw new DomainException("There is no such option on that question.");
        }

        await sittings.SaveAnswerAsync(request.SittingId, request.Position, request.SelectedIndex, cancellationToken);
    }
}
