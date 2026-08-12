using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/students")]
public class AdminStudentsController : ControllerBase
{
    private readonly IStudentService _service;
    public AdminStudentsController(IStudentService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? className, CancellationToken ct)
        => Ok(await _service.ListAsync(search, className, ct));

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        var s = await _service.GetAsync(id, ct);
        return s is null ? NotFound() : Ok(s);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveStudentDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateAsync(dto, ct) });

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
