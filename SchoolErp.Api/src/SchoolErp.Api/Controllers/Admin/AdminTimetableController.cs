using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

/// <summary>
/// The school's timetable. Editing lives here rather than in the teacher portal because a
/// timetable is school-wide: only from here can a clash between two sections be seen.
/// </summary>
[ApiController]
[Route("api/admin/timetable")]
[Authorize(Roles = "school_admin")]
public class AdminTimetableController : ControllerBase
{
    private readonly ITimetableAdminService _service;
    public AdminTimetableController(ITimetableAdminService service) => _service = service;

    /// <summary>One section's week, with the period columns and the subjects it can hold.</summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] string className, [FromQuery] string sectionName,
        CancellationToken ct)
        => Ok(await _service.GetAsync(className, sectionName, ct));

    /// <summary>Every section's periods for one day — the whole-school grid.</summary>
    [HttpGet("day/{dayOfWeek:int}")]
    public async Task<IActionResult> Day(int dayOfWeek, CancellationToken ct)
        => Ok(await _service.GetDayAsync(dayOfWeek, ct));

    /// <summary>One teacher's week — the view for scheduling them across several classes.</summary>
    [HttpGet("teacher/{staffId:long}")]
    public async Task<IActionResult> ForTeacher(long staffId, CancellationToken ct)
        => Ok(await _service.GetForTeacherAsync(staffId, ct));

    /// <summary>Suggests subjects for the day's empty periods, without double-booking a teacher.</summary>
    [HttpPost("day/{dayOfWeek:int}/autofill")]
    public async Task<IActionResult> AutoFill(int dayOfWeek, CancellationToken ct)
        => Ok(await _service.AutoFillDayAsync(dayOfWeek, ct));

    /// <summary>Sets which days of the week the school runs.</summary>
    [HttpPut("working-days")]
    public async Task<IActionResult> SetWorkingDays([FromBody] SaveWorkingDaysDto dto, CancellationToken ct)
    {
        await _service.SetWorkingDaysAsync(dto, ct);
        return NoContent();
    }

    /// <summary>Clears the grid — one day, or the whole week. Periods and working days survive.</summary>
    [HttpPost("reset")]
    public async Task<IActionResult> Reset([FromBody] ResetTimetableDto dto, CancellationToken ct)
        => Ok(await _service.ResetAsync(dto, ct));

    /* ---- period columns: how long the school day is and how it is divided ---- */

    /// <summary>The school's periods, each with the duration it runs for.</summary>
    [HttpGet("periods")]
    public async Task<IActionResult> Periods(CancellationToken ct)
        => Ok(await _service.GetPeriodsAsync(ct));

    /// <summary>Adds a period. Its place in the day follows from its start time.</summary>
    [HttpPost("periods")]
    public async Task<IActionResult> CreatePeriod([FromBody] SavePeriodDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreatePeriodAsync(dto, ct) });

    [HttpPut("periods/{id:long}")]
    public async Task<IActionResult> UpdatePeriod(long id, [FromBody] SavePeriodDto dto, CancellationToken ct)
    {
        await _service.UpdatePeriodAsync(id, dto, ct);
        return NoContent();
    }

    [HttpDelete("periods/{id:long}")]
    public async Task<IActionResult> DeletePeriod(long id, CancellationToken ct)
    {
        await _service.DeletePeriodAsync(id, ct);
        return NoContent();
    }

    [HttpPut("slot")]
    public async Task<IActionResult> SaveSlot([FromBody] SaveTimetableSlotDto dto, CancellationToken ct)
    {
        await _service.SaveSlotAsync(dto, ct);
        return NoContent();
    }
}
