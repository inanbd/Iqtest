using MediatR;

namespace IqTest.Application.Reference;

/// <summary>The country list, for the join form and the board's filter.</summary>
public sealed record GetCountriesQuery : IRequest<IReadOnlyList<Country>>;

public sealed class GetCountriesHandler : IRequestHandler<GetCountriesQuery, IReadOnlyList<Country>>
{
    public Task<IReadOnlyList<Country>> Handle(GetCountriesQuery request, CancellationToken cancellationToken)
        => Task.FromResult(Countries.All);
}
