using System.Reflection;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace IqTest.Infrastructure.Persistence;

/// <summary>
/// Applies the embedded SQL scripts in order at start-up.
///
/// Without EF there is no migrations runner, so the scripts are written to be
/// idempotent and are simply replayed: each one checks for what it creates.
/// </summary>
public sealed class DatabaseMigrator(ISqlConnectionFactory connections, ILogger<DatabaseMigrator> logger)
{
    public async Task MigrateAsync(CancellationToken cancellationToken = default)
    {
        await EnsureDatabaseExistsAsync(cancellationToken);

        var assembly = typeof(DatabaseMigrator).Assembly;
        var scripts = assembly.GetManifestResourceNames()
            .Where(name => name.Contains(".Migrations.", StringComparison.Ordinal) && name.EndsWith(".sql", StringComparison.Ordinal))
            .OrderBy(name => name, StringComparer.Ordinal)
            .ToList();

        if (scripts.Count == 0)
            throw new InvalidOperationException("No migration scripts were embedded in the assembly.");

        await using var connection = connections.Create();
        await connection.OpenAsync(cancellationToken);

        foreach (var script in scripts)
        {
            logger.LogInformation("Applying migration {Script}", script);
            var sql = await ReadAsync(assembly, script);

            // SqlClient does not understand GO, so the script is split on it.
            foreach (var batch in SplitBatches(sql))
            {
                await using var command = new SqlCommand(batch, connection) { CommandTimeout = 120 };
                await command.ExecuteNonQueryAsync(cancellationToken);
            }
        }
    }

    /// <summary>
    /// Creates the database if it is not there yet, by connecting to master.
    ///
    /// The schema scripts connect to the target database, so on a clean server
    /// there would be nothing to connect to. A first run therefore works with
    /// only a server and a login, rather than needing a manual CREATE DATABASE.
    /// </summary>
    private async Task EnsureDatabaseExistsAsync(CancellationToken cancellationToken)
    {
        var target = new SqlConnectionStringBuilder(connections.Create().ConnectionString);
        var databaseName = target.InitialCatalog;

        if (string.IsNullOrWhiteSpace(databaseName) ||
            databaseName.Equals("master", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var master = new SqlConnectionStringBuilder(target.ConnectionString) { InitialCatalog = "master" };

        await using var connection = new SqlConnection(master.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        // The name comes from configuration, not from a request, but it is still
        // quoted rather than concatenated raw.
        await using var command = new SqlCommand(
            """
            IF DB_ID(@name) IS NULL
            BEGIN
                DECLARE @sql NVARCHAR(MAX) = N'CREATE DATABASE ' + QUOTENAME(@name);
                EXEC sp_executesql @sql;
            END
            """, connection) { CommandTimeout = 120 };
        command.Parameters.AddWithValue("@name", databaseName);

        var created = await command.ExecuteNonQueryAsync(cancellationToken);
        if (created >= 0) logger.LogInformation("Ensured database {Database} exists", databaseName);
    }

    private static async Task<string> ReadAsync(Assembly assembly, string resource)
    {
        await using var stream = assembly.GetManifestResourceStream(resource)
            ?? throw new InvalidOperationException($"Migration {resource} could not be read.");
        using var reader = new StreamReader(stream);
        return await reader.ReadToEndAsync();
    }

    internal static IEnumerable<string> SplitBatches(string sql) => sql
        .Split(["\nGO\r\n", "\nGO\n", "\nGO"], StringSplitOptions.None)
        .Select(batch => batch.Trim())
        .Where(batch => batch.Length > 0);
}
