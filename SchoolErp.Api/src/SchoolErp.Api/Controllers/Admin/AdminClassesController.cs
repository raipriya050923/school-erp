using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/classes")]
[Authorize(Roles = "school_admin")]
public class AdminClassesController : ControllerBase
{
    private readonly IClassService _service;
    public AdminClassesController(IClassService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await _service.ListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> CreateClass([FromBody] CreateClassDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateClassAsync(dto, ct) });

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Rename(long id, [FromBody] RenameClassDto dto, CancellationToken ct)
    {
        await _service.RenameClassAsync(id, dto.Name, ct);
        return NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> DeleteClass(long id, CancellationToken ct)
    {
        await _service.DeleteClassAsync(id, ct);
        return NoContent();
    }

    [HttpPost("sections")]
    public async Task<IActionResult> AddSection([FromBody] SaveSectionDto dto, CancellationToken ct)
        => Ok(new { id = await _service.AddSectionAsync(dto, ct) });

    [HttpPut("sections/{id:long}")]
    public async Task<IActionResult> UpdateSection(long id, [FromBody] SaveSectionDto dto, CancellationToken ct)
    {
        await _service.UpdateSectionAsync(id, dto, ct);
        return NoContent();
    }

    [HttpDelete("sections/{id:long}")]
    public async Task<IActionResult> DeleteSection(long id, CancellationToken ct)
    {
        await _service.DeleteSectionAsync(id, ct);
        return NoContent();
    }
}
