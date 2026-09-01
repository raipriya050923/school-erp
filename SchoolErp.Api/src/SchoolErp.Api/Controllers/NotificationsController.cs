using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

/// <summary>
/// The signed-in user's notification bell. Open to every portal — the feed is scoped to the
/// caller's own user id, so no role check is needed beyond being authenticated.
/// </summary>
[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly INotificationCenter _center;
    public NotificationsController(INotificationCenter center) => _center = center;

    [HttpGet]
    public async Task<IActionResult> Feed(CancellationToken ct) => Ok(await _center.GetFeedAsync(ct));

    [HttpPost("{id:long}/read")]
    public async Task<IActionResult> MarkRead(long id, CancellationToken ct)
    {
        await _center.MarkReadAsync(id, ct);
        return NoContent();
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken ct)
    {
        await _center.MarkAllReadAsync(ct);
        return NoContent();
    }
}
