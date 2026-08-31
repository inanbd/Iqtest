using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace IqTest.Infrastructure.Persistence;

public sealed class DatabaseOptions
{
    public const string SectionName = "Database";

    /// <summary>The SQL Server connection string.</summary>
    public string ConnectionString { get; set; } = string.Empty;

    /// <summary>Whether to apply the schema scripts at start-up.</summary>
    public bool MigrateOnStartup { get; set; } = true;
}

/// <summary>Hands out connections, so repositories do not know how to build one.</summary>
public interface ISqlConnectionFactory
{
    SqlConnection Create();
}

public sealed class SqlConnectionFactory(IOptions<DatabaseOptions> options) : ISqlConnectionFactory
{
    private readonly string _connectionString = string.IsNullOrWhiteSpace(options.Value.ConnectionString)
        ? throw new InvalidOperationException("Database:ConnectionString is not configured.")
        : options.Value.ConnectionString;

    public SqlConnection Create() => new(_connectionString);
}
