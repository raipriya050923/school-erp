using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/notices")]
public class AdminNoticesController : ControllerBase
{
    private readonly INoticeService _service;
    public AdminNoticesController(INoticeService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await _service.ListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateNoticeDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateAsync(dto, ct) });
}
