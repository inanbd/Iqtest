using Dapper;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace IqTest.Web.Tests;

/// <summary>
/// Hosts the real application in memory, against a throwaway database and the
/// real shared question bank — so these tests exercise the actual wiring
/// rather than a stand-in for it.
/// </summary>
public sealed class WebFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private static string MasterConnectionString =>
        Environment.GetEnvironmentVariable("IQTEST_SQL_MASTER")
        ?? "Server=127.0.0.1,1433;Database=master;User Id=sa;Password=IqTest!Local2026;TrustServerCertificate=True;Encrypt=False";

    private readonly string _databaseName = $"IqTest_Web_{Guid.NewGuid():N}";

    public bool IsAvailable { get; private set; }
    public string? UnavailableReason { get; private set; }

    /// <summary>The shared export, found by walking up from the test binary.</summary>
    public static string QuestionBankPath
    {
        get
        {
            var directory = new DirectoryInfo(AppContext.BaseDirectory);
            while (directory is not null)
            {
                var candidate = Path.Combine(directory.FullName, "shared", "questions.json");
                if (File.Exists(candidate)) return candidate;
                directory = directory.Parent;
            }
            throw new FileNotFoundException(
                "shared/questions.json was not found. Run 'dart run tool/export_questions.dart'.");
        }
    }

    private string TargetConnectionString =>
        new SqlConnectionStringBuilder(MasterConnectionString) { InitialCatalog = _databaseName }.ConnectionString;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Database:ConnectionString"] = TargetConnectionString,
                ["Database:MigrateOnStartup"] = "true",
                ["QuestionBank:Path"] = QuestionBankPath,
            }));
    }

    public async Task InitializeAsync()
    {
        try
        {
            await using var master = new SqlConnection(MasterConnectionString);
            await master.OpenAsync();
            // The app's own migrator creates the database, so just prove the
            // server is reachable before letting the host start.
            await master.ExecuteAsync("SELECT 1;");
            _ = CreateClient();
            IsAvailable = true;
        }
        catch (Exception exception)
        {
            IsAvailable = false;
            UnavailableReason = exception.Message;
        }
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await DisposeAsync();
        if (!IsAvailable) return;
        try
        {
            await using var master = new SqlConnection(MasterConnectionString);
            await master.OpenAsync();
            await master.ExecuteAsync(
                $"ALTER DATABASE [{_databaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{_databaseName}];");
        }
        catch
        {
            // A leftover test database is not worth failing the run over.
        }
    }
}

[CollectionDefinition(Name)]
public sealed class WebCollection : ICollectionFixture<WebFactory>
{
    public const string Name = "web";
}
