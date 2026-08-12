using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/teachers")]
public class AdminTeachersController : ControllerBase
{
    private readonly ITeacherService _service;
    public AdminTeachersController(ITeacherService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, CancellationToken ct)
        => Ok(await _service.ListAsync(search, ct));

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        var t = await _service.GetAsync(id, ct);
        return t is null ? NotFound() : Ok(t);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveTeacherDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateAsync(dto, ct) });

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] SaveTeacherDto dto, CancellationToken ct)
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
