using Dapper;
using IqTest.Application.Abstractions;
using IqTest.Domain.Attempts;

namespace IqTest.Infrastructure.Persistence;

/// <summary>Writes a completed attempt and everything hanging off it.</summary>
public sealed class AttemptRepository(ISqlConnectionFactory connections) : IAttemptRepository
{
    public async Task AddAsync(Attempt attempt, CancellationToken cancellationToken)
    {
        await using var connection = connections.Create();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        if (attempt.Participant is { } participant)
        {
            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO dbo.Participants (Id, DisplayName, CountryCode, Email, CreatedAtUtc)
                VALUES (@Id, @DisplayName, @CountryCode, @Email, @CreatedAtUtc);
                """,
                new
                {
                    participant.Id,
                    participant.DisplayName,
                    participant.CountryCode,
                    participant.Email,
                    participant.CreatedAtUtc,
                },
                transaction, cancellationToken: cancellationToken));
        }

        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO dbo.Attempts
                (Id, CertificateSlug, ParticipantId, Format, Platform, ScoreIndex, Percentile,
                 CorrectCount, TotalCount, WeightedPoints, MaxWeightedPoints, DurationSeconds,
                 IsRanked, CompletedAtUtc)
            VALUES
                (@Id, @CertificateSlug, @ParticipantId, @Format, @Platform, @ScoreIndex, @Percentile,
                 @CorrectCount, @TotalCount, @WeightedPoints, @MaxWeightedPoints, @DurationSeconds,
                 @IsRanked, @CompletedAtUtc);
            """,
            new
            {
                attempt.Id,
                CertificateSlug = attempt.Slug.Value,
                ParticipantId = attempt.Participant?.Id,
                Format = (byte)attempt.Format,
                Platform = (byte)attempt.Platform,
                ScoreIndex = attempt.Score.Index,
                Percentile = Math.Round(attempt.Score.Percentile, 2),
                CorrectCount = attempt.Score.Correct,
                TotalCount = attempt.Score.Total,
                WeightedPoints = attempt.Score.WeightedPoints,
                MaxWeightedPoints = attempt.Score.MaxWeightedPoints,
                DurationSeconds = (int)attempt.Duration.TotalSeconds,
                attempt.IsRanked,
                attempt.CompletedAtUtc,
            },
            transaction, cancellationToken: cancellationToken));

        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO dbo.AttemptCategoryScores (AttemptId, Category, Correct, Total)
            VALUES (@AttemptId, @Category, @Correct, @Total);
            """,
            attempt.Score.ByCategory.Select(c => new
            {
                AttemptId = attempt.Id,
                Category = (byte)c.Category,
                c.Correct,
                c.Total,
            }),
            transaction, cancellationToken: cancellationToken));

        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO dbo.AttemptAnswers (AttemptId, Position, QuestionId, SelectedIndex, IsCorrect)
            VALUES (@AttemptId, @Position, @QuestionId, @SelectedIndex, @IsCorrect);
            """,
            attempt.Answers.Select((answer, position) => new
            {
                AttemptId = attempt.Id,
                Position = position,
                answer.QuestionId,
                answer.SelectedIndex,
                answer.IsCorrect,
            }),
            transaction, cancellationToken: cancellationToken));

        await transaction.CommitAsync(cancellationToken);
    }
}
