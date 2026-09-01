using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/staff-attendance")]
[Authorize(Roles = "school_admin")]
public class AdminStaffAttendanceController : ControllerBase
{
    private readonly IStaffAttendanceService _service;
    private readonly ISchoolClock _clock;
    public AdminStaffAttendanceController(IStaffAttendanceService service, ISchoolClock clock)
    {
        _service = service;
        _clock = clock;
    }

    /// <summary>
    /// Every active staff member for the date, pre-filled with what was saved — or with
    /// <c>on_leave</c> where an approved leave covers that day.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] DateTime date, CancellationToken ct)
        => Ok(await _service.GetAsync(date == default ? await _clock.TodayAsync(ct) : date, ct));

    [HttpPost]
    public async Task<IActionResult> Save([FromBody] SaveStaffAttendanceDto dto, CancellationToken ct)
    {
        await _service.SaveAsync(dto, ct);
        return NoContent();
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary([FromQuery] DateTime from, [FromQuery] DateTime to, CancellationToken ct)
    {
        var today = await _clock.TodayAsync(ct);
        return Ok(await _service.SummaryAsync(
            from == default ? new DateTime(today.Year, today.Month, 1) : from,
            to == default ? today : to, ct));
    }
}
