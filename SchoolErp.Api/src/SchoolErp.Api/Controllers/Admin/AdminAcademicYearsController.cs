using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

/// <summary>
/// Manages the school's academic years. The read-only list used by the top-bar year picker
/// lives at /api/academic-years and is open to every portal; this one is admin-only and writes.
/// </summary>
[ApiController]
[Route("api/admin/academic-years")]
[Authorize(Roles = "school_admin")]
public class AdminAcademicYearsController : ControllerBase
{
    private readonly IAcademicYearService _service;
    public AdminAcademicYearsController(IAcademicYearService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await _service.ListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveAcademicYearDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateAsync(dto, ct) });

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] SaveAcademicYearDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>Makes this the current year; the previous one is cleared.</summary>
    [HttpPatch("{id:long}/current")]
    public async Task<IActionResult> SetCurrent(long id, CancellationToken ct)
    {
        await _service.SetCurrentAsync(id, ct);
        return NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken ct)
    {
        await _service.DeleteAsync(id, ct);
        return NoContent();
    }
}
