using System.Buffers.Text;
using IqTest.Domain.Common;

namespace IqTest.Domain.Attempts;

/// <summary>
/// The unguessable id in a certificate's public URL.
///
/// 22 URL-safe characters carrying 128 bits, so a certificate link can be
/// shared freely without the address of anyone else's being reachable by
/// guessing.
/// </summary>
public readonly record struct CertificateSlug
{
    public const int Length = 22;

    private CertificateSlug(string value) => Value = value;

    public string Value { get; }

    public static CertificateSlug NewSlug() => FromGuid(Guid.NewGuid());

    public static CertificateSlug FromGuid(Guid id)
    {
        Span<byte> bytes = stackalloc byte[16];
        id.TryWriteBytes(bytes);
        // Base64url without the two '==' of padding.
        var encoded = Convert.ToBase64String(bytes).Replace('+', '-').Replace('/', '_')[..Length];
        return new CertificateSlug(encoded);
    }

    public static CertificateSlug Parse(string value)
    {
        if (!TryParse(value, out var slug))
            throw new DomainException("That is not a certificate address.");
        return slug;
    }

    public static bool TryParse(string? value, out CertificateSlug slug)
    {
        slug = default;
        if (value is null || value.Length != Length) return false;
        foreach (var c in value)
        {
            var ok = c is >= 'A' and <= 'Z' or >= 'a' and <= 'z' or >= '0' and <= '9' or '-' or '_';
            if (!ok) return false;
        }
        slug = new CertificateSlug(value);
        return true;
    }

    public override string ToString() => Value;
}
