using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/students")]
[Authorize(Roles = "school_admin")]
public class AdminStudentsController : ControllerBase
{
    private readonly IStudentService _service;
    public AdminStudentsController(IStudentService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? className, CancellationToken ct)
        => Ok(await _service.ListAsync(search, className, ct));

    /// <summary>Next free roll number for a class/section — a preview for the admission form.</summary>
    [HttpGet("next-roll")]
    public async Task<IActionResult> NextRoll([FromQuery] string? className, [FromQuery] string? sectionName, CancellationToken ct)
        => Ok(new { rollNo = await _service.NextRollNoAsync(className, sectionName, ct) });

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        var s = await _service.GetAsync(id, ct);
        return s is null ? NotFound() : Ok(s);
    }

    /// <summary>
    /// Admits a student and provisions their portal login. The response carries the generated
    /// password in plaintext — it is never persisted or retrievable afterwards, so the caller
    /// must surface it to the admin immediately.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveStudentDto dto, CancellationToken ct)
        => Ok(await _service.CreateAsync(dto, ct));

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] SaveStudentDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    [HttpPatch("{id:long}/status")]
    public async Task<IActionResult> SetStatus(long id, [FromBody] UpdateStatusDto dto, CancellationToken ct)
    {
        await _service.SetStatusAsync(id, dto.Status, ct);
        return NoContent();
    }
}
