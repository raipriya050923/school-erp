using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/notices")]
[Authorize(Roles = "school_admin")]
public class AdminNoticesController : ControllerBase
{
    private readonly INoticeService _service;
    public AdminNoticesController(INoticeService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await _service.ListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateNoticeDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateAsync(dto, ct) });

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] CreateNoticeDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken ct)
    {
        await _service.DeleteAsync(id, ct);
        return NoContent();
    }
}
