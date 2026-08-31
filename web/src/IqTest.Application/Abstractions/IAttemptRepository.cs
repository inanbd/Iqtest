using IqTest.Domain.Attempts;

namespace IqTest.Application.Abstractions;

/// <summary>The write side for completed, scored attempts.</summary>
public interface IAttemptRepository
{
    Task AddAsync(Attempt attempt, CancellationToken cancellationToken);
}
