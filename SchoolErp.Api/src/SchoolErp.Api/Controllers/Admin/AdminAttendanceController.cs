using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/attendance")]
public class AdminAttendanceController : ControllerBase
{
    private readonly IAdminAttendanceService _service;
    public AdminAttendanceController(IAdminAttendanceService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] string className, [FromQuery] string sectionName, [FromQuery] DateTime date, CancellationToken ct)
        => Ok(await _service.GetAsync(className, sectionName, date, ct));

    [HttpPost]
    public async Task<IActionResult> Save([FromBody] SaveAttendanceDto dto, CancellationToken ct)
    {
        await _service.SaveAsync(dto, ct);
        return NoContent();
    }

    [HttpGet("report")]
    public async Task<IActionResult> Report([FromQuery] long studentId, [FromQuery] DateTime from, [FromQuery] DateTime to, CancellationToken ct)
        => Ok(await _service.ReportAsync(studentId, from, to, ct));
}
