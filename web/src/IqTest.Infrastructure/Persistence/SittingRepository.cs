using Dapper;
using IqTest.Application.Abstractions;
using IqTest.Domain.Questions;

namespace IqTest.Infrastructure.Persistence;

/// <summary>
/// Persists tests in progress. Server-side rather than in a cookie, so what
/// was issued cannot be edited by the candidate and a sitting survives a
/// restart or a move between instances.
/// </summary>
public sealed class SittingRepository(ISqlConnectionFactory connections) : ISittingRepository
{
    public async Task CreateAsync(Sitting sitting, CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO dbo.Sittings (Id, Format, VisitorKey, StartedAtUtc, ExpiresAtUtc)
            VALUES (@Id, @Format, @VisitorKey, @StartedAtUtc, @ExpiresAtUtc);
            """,
            new
            {
                sitting.Id,
                Format = (byte)sitting.Format,
                sitting.VisitorKey,
                sitting.StartedAtUtc,
                sitting.ExpiresAtUtc,
            },
            transaction, cancellationToken: cancellationToken));

        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO dbo.SittingItems (SittingId, Position, QuestionId, SelectedIndex)
            VALUES (@SittingId, @Position, @QuestionId, NULL);
            """,
            sitting.QuestionIds.Select((id, position) => new
            {
                SittingId = sitting.Id,
                Position = position,
                QuestionId = id,
            }),
            transaction, cancellationToken: cancellationToken));

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<Sitting?> FindAsync(Guid sittingId, CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();

        var header = await connection.QuerySingleOrDefaultAsync<SittingRow>(new CommandDefinition(
            """
            SELECT Id, Format, VisitorKey, StartedAtUtc, ExpiresAtUtc, SubmittedAtUtc
            FROM dbo.Sittings
            WHERE Id = @sittingId;
            """,
            new { sittingId }, cancellationToken: cancellationToken));

        if (header is null) return null;

        var items = (await connection.QueryAsync<SittingItemRow>(new CommandDefinition(
            """
            SELECT Position, QuestionId, SelectedIndex
            FROM dbo.SittingItems
            WHERE SittingId = @sittingId
            ORDER BY Position;
            """,
            new { sittingId }, cancellationToken: cancellationToken))).ToList();

        var sitting = new Sitting(
            header.Id,
            (TestFormat)header.Format,
            items.Select(i => i.QuestionId).ToList(),
            header.StartedAtUtc,
            header.ExpiresAtUtc,
            header.VisitorKey)
        {
            SubmittedAtUtc = header.SubmittedAtUtc,
        };

        foreach (var item in items)
            sitting.Answers[item.Position] = item.SelectedIndex;

        return sitting;
    }

    public async Task SaveAnswerAsync(Guid sittingId, int position, int? selectedIndex, CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();
        await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE dbo.SittingItems
            SET SelectedIndex = @selectedIndex
            WHERE SittingId = @sittingId AND Position = @position;
            """,
            new { sittingId, position, selectedIndex }, cancellationToken: cancellationToken));
    }

    public async Task MarkSubmittedAsync(Guid sittingId, DateTimeOffset submittedAtUtc, CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();
        await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE dbo.Sittings
            SET SubmittedAtUtc = @submittedAtUtc
            WHERE Id = @sittingId AND SubmittedAtUtc IS NULL;
            """,
            new { sittingId, submittedAtUtc }, cancellationToken: cancellationToken));
    }

    public async Task<IReadOnlySet<string>> RecentItemIdsAsync(string? visitorKey, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(visitorKey)) return new HashSet<string>();

        await using var connection = connections.Create();
        var ids = await connection.QueryAsync<string>(new CommandDefinition(
            """
            SELECT i.QuestionId
            FROM dbo.SittingItems i
            WHERE i.SittingId = (
                SELECT TOP (1) s.Id
                FROM dbo.Sittings s
                WHERE s.VisitorKey = @visitorKey
                ORDER BY s.StartedAtUtc DESC
            );
            """,
            new { visitorKey }, cancellationToken: cancellationToken));

        return ids.ToHashSet(StringComparer.Ordinal);
    }

    private sealed record SittingRow(
        Guid Id,
        byte Format,
        string? VisitorKey,
        DateTimeOffset StartedAtUtc,
        DateTimeOffset ExpiresAtUtc,
        DateTimeOffset? SubmittedAtUtc);

    private sealed record SittingItemRow(int Position, string QuestionId, int? SelectedIndex);
}
