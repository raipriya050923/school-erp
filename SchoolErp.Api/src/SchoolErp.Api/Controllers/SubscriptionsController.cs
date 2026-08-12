using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/super-admin/subscriptions")]
public class SubscriptionsController : ControllerBase
{
    private readonly ISubscriptionService _service;
    public SubscriptionsController(ISubscriptionService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? status, [FromQuery] long? planId, CancellationToken ct)
        => Ok(await _service.ListAsync(status, planId, ct));
}
