using System.Text.Json;
using SchoolErp.Application.Common;

namespace SchoolErp.Api.Middleware;

/// <summary>
/// Refuses every request from a token still carrying <see cref="ErpClaims.MustChangePassword"/>,
/// except the handful needed to change it.
///
/// Enforced here rather than in the client: a route guard stops an honest user navigating, but
/// the token is a valid bearer token and would otherwise open every endpoint to anyone holding
/// the password an administrator issued. The 403 names the reason so the client can route to the
/// change screen instead of showing a generic denial.
/// </summary>
public class PasswordChangeRequiredMiddleware
{
    /// <summary>
    /// What a user in this state may still reach: their own identity, changing the password, and
    /// signing out. Anything else waits until the flag clears.
    /// </summary>
    private static readonly string[] Allowed =
    {
        "/api/auth/login",
        "/api/auth/change-password",
        "/api/auth/forgot-password",
        "/api/auth/reset-password",
        "/api/auth/me",
    };

    private readonly RequestDelegate _next;
    public PasswordChangeRequiredMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        var user = context.User;
        if (user?.Identity?.IsAuthenticated == true
            && user.FindFirst(ErpClaims.MustChangePassword)?.Value == "1"
            && !IsAllowed(context.Request.Path))
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsync(JsonSerializer.Serialize(new
            {
                error = "password_change_required",
                message = "Set your own password before continuing. The one you signed in with was issued by your school.",
            }));
            return;
        }
        await _next(context);
    }

    private static bool IsAllowed(PathString path) =>
        Allowed.Any(a => path.StartsWithSegments(a, StringComparison.OrdinalIgnoreCase));
}
