using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IqTest.Web.Pages;

public sealed class ErrorModel : PageModel
{
    public int StatusCode { get; private set; } = 500;
    public string? Detail { get; private set; }

    public string Title => StatusCode switch
    {
        400 => "That request could not be accepted",
        404 => "Nothing lives at this address",
        _ => "Something went wrong",
    };

    public void OnGet(int? code, string? message)
    {
        StatusCode = code ?? 500;
        Detail = message;
    }
}
