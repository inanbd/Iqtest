using IqTest.Application.Abstractions;
using IqTest.Infrastructure.Persistence;
using IqTest.Infrastructure.Questions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace IqTest.Infrastructure;

public sealed class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}

public sealed class GuidIdentityGenerator : IIdentityGenerator
{
    public Guid NewId() => Guid.NewGuid();
}

public static class DependencyInjection
{
    /// <summary>
    /// Binds the application's ports to SQL Server and the shared question
    /// bank. This is the only project that knows either exists.
    /// </summary>
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        string contentRootPath)
    {
        services.Configure<DatabaseOptions>(configuration.GetSection(DatabaseOptions.SectionName));
        services.Configure<QuestionBankOptions>(configuration.GetSection(QuestionBankOptions.SectionName));

        services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
        services.AddSingleton<DatabaseMigrator>();

        services.AddScoped<IAttemptRepository, AttemptRepository>();
        services.AddScoped<ISittingRepository, SittingRepository>();
        services.AddScoped<LeaderboardReadStore>();
        services.AddScoped<ILeaderboardReadStore>(sp => sp.GetRequiredService<LeaderboardReadStore>());
        services.AddScoped<ICertificateReadStore>(sp => sp.GetRequiredService<LeaderboardReadStore>());

        // The bank is immutable, so it is read once at start-up.
        services.AddSingleton<IQuestionBank>(sp =>
        {
            var options = sp.GetRequiredService<IOptions<QuestionBankOptions>>().Value;
            var path = Path.IsPathRooted(options.Path)
                ? options.Path
                : Path.Combine(contentRootPath, options.Path);
            return new JsonQuestionBank(Path.GetFullPath(path));
        });

        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<IIdentityGenerator, GuidIdentityGenerator>();

        return services;
    }
}
