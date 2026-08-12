using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/super-admin/schools")]
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

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateSchoolDto dto, CancellationToken ct)
    {
        var id = await _service.CreateAsync(dto, ct);
        return CreatedAtAction(nameof(Get), new { id }, new { id });
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] UpdateSchoolDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>Activate / suspend / terminate a school.</summary>
    [HttpPatch("{id:long}/status")]
    public async Task<IActionResult> ChangeStatus(long id, [FromBody] UpdateStatusDto dto, CancellationToken ct)
    {
        await _service.ChangeStatusAsync(id, dto.Status, ct);
        return NoContent();
    }
}
