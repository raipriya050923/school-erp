using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/subjects")]
[Authorize(Roles = "school_admin")]
public class AdminSubjectsController : ControllerBase
{
    private readonly ISubjectService _service;
    public AdminSubjectsController(ISubjectService service) => _service = service;

    /// <summary>Every subject this school has, active or retired.</summary>
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await _service.ListAsync(ct));

    /// <summary>Active names only — drives the exam Add Subject dropdown.</summary>
    [HttpGet("names")]
    public async Task<IActionResult> Names(CancellationToken ct) => Ok(await _service.ActiveNamesAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveSubjectDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateAsync(dto, ct) });

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] SaveSubjectDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>
    /// Retire or restore a subject. Retiring hides it from the exam dropdown but leaves existing
    /// exam papers alone — they record the subject as text, so past schedules stay readable.
    /// </summary>
    [HttpPatch("{id:long}/active")]
    public async Task<IActionResult> SetActive(long id, [FromQuery] bool value, CancellationToken ct)
    {
        await _service.SetActiveAsync(id, value, ct);
        return NoContent();
    }
}
