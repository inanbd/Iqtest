using IqTest.Domain.Common;

namespace IqTest.Web.Infrastructure;

/// <summary>
/// Turns a broken domain rule into a 400 with a readable message, rather than
/// a 500. Keeps the handlers free of HTTP concerns.
/// </summary>
public sealed class DomainExceptionMiddleware(RequestDelegate next, ILogger<DomainExceptionMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (DomainException exception)
        {
            logger.LogInformation(exception, "Rejected a request: {Message}", exception.Message);

            if (context.Response.HasStarted) throw;

            context.Response.Clear();
            context.Response.StatusCode = StatusCodes.Status400BadRequest;

            if (context.Request.Path.StartsWithSegments("/api"))
            {
                await context.Response.WriteAsJsonAsync(new
                {
                    error = exception.Message,
                    type = exception is InvalidSubmissionException ? "invalid_submission" : "invalid_request",
                });
            }
            else
            {
                context.Response.Redirect($"/Error/400?message={Uri.EscapeDataString(exception.Message)}");
            }
        }
    }
}
