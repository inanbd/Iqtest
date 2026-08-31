using IqTest.Application.Common;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace IqTest.Application;

/// <summary>Marks this assembly for handler discovery.</summary>
public interface IApplicationMarker;

public static class DependencyInjection
{
    /// <summary>
    /// Registers every command and query handler in this assembly, plus the
    /// pipeline. Infrastructure supplies the interfaces they depend on.
    /// </summary>
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddMediatR(configuration =>
        {
            configuration.RegisterServicesFromAssemblyContaining<IApplicationMarker>();
            configuration.AddOpenBehavior(typeof(ParticipantValidationBehaviour<,>));
        });

        return services;
    }
}
