namespace IqTest.Web.Infrastructure;

/// <summary>
/// An opaque per-browser id, kept in a cookie so a returning visitor's draw
/// can hold back the items they last saw — the same freshness rule the mobile
/// app applies. It identifies a browser, not a person, and is not tied to any
/// personal data.
/// </summary>
public static class VisitorKey
{
    public const string CookieName = "iq_visitor";

    public static string GetOrCreate(HttpContext context)
    {
        if (context.Request.Cookies.TryGetValue(CookieName, out var existing) &&
            !string.IsNullOrWhiteSpace(existing) &&
            existing.Length <= 64)
        {
            return existing;
        }

        var key = Guid.NewGuid().ToString("N");
        context.Response.Cookies.Append(CookieName, key, new CookieOptions
        {
            HttpOnly = true,
            IsEssential = true,
            SameSite = SameSiteMode.Lax,
            Secure = context.Request.IsHttps,
            Expires = DateTimeOffset.UtcNow.AddYears(1),
        });
        return key;
    }
}
