using IqTest.Domain.Questions;

namespace IqTest.Application.Abstractions;

/// <summary>Supplies the item pool. Implemented in Infrastructure.</summary>
public interface IQuestionBank
{
    QuestionPool Pool { get; }
}

/// <summary>The current time, injected so handlers stay testable.</summary>
public interface IClock
{
    DateTimeOffset UtcNow { get; }
}

/// <summary>Identity generation, injected so tests can make attempts deterministic.</summary>
public interface IIdentityGenerator
{
    Guid NewId();
}
