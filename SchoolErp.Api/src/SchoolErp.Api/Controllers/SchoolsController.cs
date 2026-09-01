using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/super-admin/schools")]
[Authorize(Roles = "super_admin")]
public class SchoolsController : ControllerBase
{
    private readonly ISchoolService _service;
    public SchoolsController(ISchoolService service) => _service = service;

    /// <summary>List schools, optionally filtered by search text or status.</summary>
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status, CancellationToken ct)
        => Ok(await _service.ListAsync(search, status, ct));

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        var school = await _service.GetAsync(id, ct);
        return school is null ? NotFound() : Ok(school);
    }

    /// <summary>
    /// Onboards a school and provisions its first school_admin login. The response carries the
    /// generated password in plaintext — it is never persisted or retrievable afterwards, so the
    /// caller must surface it to the super admin immediately.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateSchoolDto dto, CancellationToken ct)
    {
        var result = await _service.CreateAsync(dto, ct);
        return CreatedAtAction(nameof(Get), new { id = result.SchoolId }, result);
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] UpdateSchoolDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>
    /// Issues a new password for the school's administrator and returns it once. The previous
    /// password is unrecoverable by design, so this is the only way to restore access.
    /// </summary>
    [HttpPost("{id:long}/admin/reset-password")]
    public async Task<IActionResult> ResetAdminPassword(long id, CancellationToken ct)
        => Ok(await _service.ResetAdminPasswordAsync(id, ct));

    /// <summary>Activate / suspend / terminate a school.</summary>
    [HttpPatch("{id:long}/status")]
    public async Task<IActionResult> ChangeStatus(long id, [FromBody] UpdateStatusDto dto, CancellationToken ct)
    {
        await _service.ChangeStatusAsync(id, dto.Status, ct);
        return NoContent();
    }
}
