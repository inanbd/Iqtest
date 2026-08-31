using IqTest.Application.Common;
using IqTest.Application.Reference;
using IqTest.Domain.Attempts;
using IqTest.Domain.Common;
using MediatR;

namespace IqTest.Application.Common;

/// <summary>
/// Checks the details a participant supplies before any handler runs, so the
/// rules live in one place rather than in each entry point.
/// </summary>
public sealed class ParticipantValidationBehaviour<TRequest, TResponse>
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (GetParticipant(request) is { } details)
        {
            if (string.IsNullOrWhiteSpace(details.DisplayName))
                throw new DomainException("A display name is required to appear on the leaderboard.");
            if (details.DisplayName.Trim().Length > Participant.MaxNameLength)
                throw new DomainException($"A display name can be at most {Participant.MaxNameLength} characters.");
            if (!Countries.IsKnown(details.CountryCode))
                throw new DomainException("Please choose a country from the list.");
        }

        return next();
    }

    private static ParticipantDetails? GetParticipant(TRequest request) => request switch
    {
        Sittings.Commands.SubmitSittingCommand c => c.Participant,
        Sittings.Commands.SubmitExternalAttemptCommand c => c.Participant,
        _ => null,
    };
}
