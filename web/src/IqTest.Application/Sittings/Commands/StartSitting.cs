using IqTest.Application.Abstractions;
using IqTest.Domain.Attempts;
using IqTest.Domain.Questions;
using MediatR;

namespace IqTest.Application.Sittings.Commands;

/// <summary>
/// Issues a sitting. The server picks the items and remembers them, so a web
/// submission can be scored against what was actually presented.
/// </summary>
/// <param name="Format">Full or quick.</param>
/// <param name="VisitorKey">
/// Opaque per-browser key. The draw holds back the items this visitor last
/// saw, matching the mobile app's behaviour.
/// </param>
public sealed record StartSittingCommand(TestFormat Format, string? VisitorKey)
    : IRequest<StartSittingResult>;

public sealed record StartSittingResult(Guid SittingId, int QuestionCount, TimeSpan TimeLimit);

public sealed class StartSittingHandler(
    IQuestionBank bank,
    ISittingRepository sittings,
    IClock clock,
    IIdentityGenerator ids)
    : IRequestHandler<StartSittingCommand, StartSittingResult>
{
    public async Task<StartSittingResult> Handle(StartSittingCommand request, CancellationToken cancellationToken)
    {
        var blueprint = TestBlueprint.For(request.Format);
        var avoid = await sittings.RecentItemIdsAsync(request.VisitorKey, cancellationToken);

        var questions = bank.Pool.Draw(blueprint, avoid);
        var now = clock.UtcNow;

        var sitting = new Sitting(
            ids.NewId(),
            request.Format,
            questions.Select(q => q.Id).ToList(),
            now,
            // A little slack past the limit, so a submission that lands as the
            // clock runs out is still accepted rather than lost.
            now + blueprint.TimeLimit + TimeSpan.FromMinutes(2),
            request.VisitorKey);

        await sittings.CreateAsync(sitting, cancellationToken);

        return new StartSittingResult(sitting.Id, questions.Count, blueprint.TimeLimit);
    }
}
