namespace IqTest.Domain.Common;

/// <summary>A rule of the domain was broken by the caller.</summary>
public class DomainException(string message) : Exception(message);

/// <summary>A submission did not match the blueprint it claimed to follow.</summary>
public sealed class InvalidSubmissionException(string message) : DomainException(message);
