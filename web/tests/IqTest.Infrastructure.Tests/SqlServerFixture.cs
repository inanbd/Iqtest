using Dapper;
using IqTest.Infrastructure.Persistence;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace IqTest.Infrastructure.Tests;

/// <summary>
/// A real SQL Server database, created once per test run and dropped after.
///
/// The repositories are hand-written SQL, so testing them against anything
/// other than SQL Server would prove very little.
/// </summary>
public sealed class SqlServerFixture : IAsyncLifetime
{
    private const string MasterConnectionEnvVar = "IQTEST_SQL_MASTER";

    private static string MasterConnectionString =>
        Environment.GetEnvironmentVariable(MasterConnectionEnvVar)
        ?? "Server=127.0.0.1,1433;Database=master;User Id=sa;Password=IqTest!Local2026;TrustServerCertificate=True;Encrypt=False";

    public string DatabaseName { get; } = $"IqTest_Test_{Guid.NewGuid():N}";

    public string ConnectionString { get; private set; } = string.Empty;

    public ISqlConnectionFactory Connections { get; private set; } = null!;

    /// <summary>False when no SQL Server is reachable, so tests can skip rather than fail.</summary>
    public bool IsAvailable { get; private set; }

    public string? UnavailableReason { get; private set; }

    public async Task InitializeAsync()
    {
        try
        {
            await using (var master = new SqlConnection(MasterConnectionString))
            {
                await master.OpenAsync();
                await master.ExecuteAsync($"CREATE DATABASE [{DatabaseName}];");
            }

            var builder = new SqlConnectionStringBuilder(MasterConnectionString)
            {
                InitialCatalog = DatabaseName,
            };
            ConnectionString = builder.ConnectionString;

            Connections = new SqlConnectionFactory(Options.Create(new DatabaseOptions
            {
                ConnectionString = ConnectionString,
            }));

            await new DatabaseMigrator(Connections, NullLogger<DatabaseMigrator>.Instance).MigrateAsync();
            IsAvailable = true;
        }
        catch (Exception ex)
        {
            IsAvailable = false;
            UnavailableReason = ex.Message;
        }
    }

    public async Task DisposeAsync()
    {
        if (!IsAvailable) return;
        try
        {
            await using var master = new SqlConnection(MasterConnectionString);
            await master.OpenAsync();
            await master.ExecuteAsync(
                $"ALTER DATABASE [{DatabaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DatabaseName}];");
        }
        catch
        {
            // A leftover test database is not worth failing the run over.
        }
    }

    /// <summary>Clears every table between tests, so each starts from empty.</summary>
    public async Task ResetAsync()
    {
        await using var connection = Connections.Create();
        await connection.ExecuteAsync(
            """
            DELETE FROM dbo.AttemptAnswers;
            DELETE FROM dbo.AttemptCategoryScores;
            DELETE FROM dbo.Attempts;
            DELETE FROM dbo.Participants;
            DELETE FROM dbo.SittingItems;
            DELETE FROM dbo.Sittings;
            """);
    }
}

[CollectionDefinition(Name)]
public sealed class SqlServerCollection : ICollectionFixture<SqlServerFixture>
{
    public const string Name = "sqlserver";
}
