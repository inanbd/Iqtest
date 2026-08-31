using System.Text.RegularExpressions;
using IqTest.Domain.Common;

namespace IqTest.Domain.Attempts;

/// <summary>
/// The little we ask for in exchange for a place on the board: a display name
/// and a country. An email address is optional, and is used only to keep one
/// person's best score rather than every attempt they make.
/// </summary>
public sealed partial class Participant
{
    public const int MaxNameLength = 40;
    public const int MaxEmailLength = 254;

    private Participant(Guid id, string displayName, string countryCode, string? email, DateTimeOffset createdAtUtc)
    {
        Id = id;
        DisplayName = displayName;
        CountryCode = countryCode;
        Email = email;
        CreatedAtUtc = createdAtUtc;
    }

    public Guid Id { get; }
    public string DisplayName { get; }

    /// <summary>ISO 3166-1 alpha-2, upper case.</summary>
    public string CountryCode { get; }

    public string? Email { get; }
    public DateTimeOffset CreatedAtUtc { get; }

    public static Participant Create(
        Guid id,
        string displayName,
        string countryCode,
        string? email,
        DateTimeOffset createdAtUtc)
    {
        displayName = (displayName ?? string.Empty).Trim();
        if (displayName.Length == 0)
            throw new DomainException("A display name is required to appear on the leaderboard.");
        if (displayName.Length > MaxNameLength)
            throw new DomainException($"A display name can be at most {MaxNameLength} characters.");

        countryCode = (countryCode ?? string.Empty).Trim().ToUpperInvariant();
        if (!CountryCodePattern().IsMatch(countryCode))
            throw new DomainException("A two-letter country code is required.");

        email = string.IsNullOrWhiteSpace(email) ? null : email.Trim();
        if (email is not null)
        {
            if (email.Length > MaxEmailLength)
                throw new DomainException($"An email address can be at most {MaxEmailLength} characters.");
            if (!EmailPattern().IsMatch(email))
                throw new DomainException("That does not look like an email address.");
        }

        return new Participant(id, displayName, countryCode, email, createdAtUtc);
    }

    public static Participant Rehydrate(Guid id, string displayName, string countryCode, string? email, DateTimeOffset createdAtUtc)
        => new(id, displayName, countryCode, email, createdAtUtc);

    [GeneratedRegex("^[A-Z]{2}$")]
    private static partial Regex CountryCodePattern();

    // Deliberately permissive: the address is optional and never relied upon,
    // so this only catches obvious mistakes.
    [GeneratedRegex(@"^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$")]
    private static partial Regex EmailPattern();
}
