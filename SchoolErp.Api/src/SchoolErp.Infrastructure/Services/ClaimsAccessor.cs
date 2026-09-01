using Microsoft.AspNetCore.Http;
using SchoolErp.Application.Common;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Reads scoping values out of the validated bearer token. <see cref="Require"/> throws rather
/// than falling back to a default — a silent fallback is what previously let every portal read
/// the same hardcoded school.
/// </summary>
internal static class ClaimsAccessor
{
    public static long Require(IHttpContextAccessor accessor, string claim, string what)
        => TryRead(accessor, claim)
           ?? throw new ForbiddenException(
               $"Your session does not carry a {what}. Sign out and sign in again.");

    public static long? TryRead(IHttpContextAccessor accessor, string claim)
    {
        var raw = accessor.HttpContext?.User.FindFirst(claim)?.Value;
        return long.TryParse(raw, out var value) ? value : null;
    }
}
