using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Tickets;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/super-admin/tickets")]
[Authorize(Roles = "super_admin")]
public class TicketsController : ControllerBase
{
    private readonly ITicketService _service;
    public TicketsController(ITicketService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? status, CancellationToken ct)
        => Ok(await _service.ListAsync(status, ct));

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        var ticket = await _service.GetAsync(id, ct);
        return ticket is null ? NotFound() : Ok(ticket);
    }

    [HttpPatch("{id:long}/status")]
    public async Task<IActionResult> ChangeStatus(long id, [FromBody] UpdateTicketStatusDto dto, CancellationToken ct)
    {
        await _service.ChangeStatusAsync(id, dto.Status, ct);
        return NoContent();
    }

    /// <summary>Resolve a ticket with a resolution note (optionally emailing the school).</summary>
    [HttpPost("{id:long}/resolve")]
    public async Task<IActionResult> Resolve(long id, [FromBody] ResolveTicketDto dto, CancellationToken ct)
    {
        // In a real app the acting user id comes from the auth token; hard-coded 1 for the demo.
        await _service.ResolveAsync(id, dto, actingUserId: 1, ct);
        return NoContent();
    }

    /// <summary>Post a comment on a ticket (super-admin side).</summary>
    [HttpPost("{id:long}/comments")]
    public async Task<IActionResult> AddComment(long id, [FromBody] AddCommentDto dto, CancellationToken ct)
        => Ok(await _service.AddCommentAsync(id, dto, ct));
}
