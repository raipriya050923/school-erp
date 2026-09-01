using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/leave")]
[Authorize(Roles = "school_admin")]
public class AdminLeaveController : ControllerBase
{
    private readonly ILeaveService _service;
    public AdminLeaveController(ILeaveService service) => _service = service;

    /// <summary>The whole school's requests, optionally narrowed to one status.</summary>
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? status, CancellationToken ct)
        => Ok(await _service.ListAsync(status, ct));

    [HttpGet("types")]
    public async Task<IActionResult> Types(CancellationToken ct) => Ok(await _service.TypesAsync(ct));

    /// <summary>Records leave for a staff member who reported it to the office rather than applying.</summary>
    [HttpPost]
    public async Task<IActionResult> ApplyForStaff([FromBody] ApplyLeaveForStaffDto dto, CancellationToken ct)
        => Ok(new { id = await _service.ApplyForStaffAsync(dto, ct) });

    /// <summary>Adds a leave type to the school's list.</summary>
    [HttpPost("types")]
    public async Task<IActionResult> CreateType([FromBody] SaveLeaveTypeDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateTypeAsync(dto, ct) });

    /// <summary>Approve or reject a pending request.</summary>
    [HttpPatch("{id:long}/review")]
    public async Task<IActionResult> Review(long id, [FromBody] ReviewLeaveDto dto, CancellationToken ct)
    {
        await _service.ReviewAsync(id, dto, ct);
        return NoContent();
    }
}
