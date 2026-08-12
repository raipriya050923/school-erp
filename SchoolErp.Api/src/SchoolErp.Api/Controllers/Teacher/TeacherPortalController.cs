using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Teacher;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Teacher;

[ApiController]
[Route("api/teacher")]
public class TeacherPortalController : ControllerBase
{
    private readonly ITeacherPortalService _service;
    public TeacherPortalController(ITeacherPortalService service) => _service = service;

    [HttpGet("dashboard/stats")]
    public async Task<IActionResult> Dashboard(CancellationToken ct) => Ok(await _service.GetDashboardAsync(ct));

    [HttpGet("profile")]
    public async Task<IActionResult> Profile(CancellationToken ct)
    {
        var p = await _service.GetProfileAsync(ct);
        return p is null ? NotFound() : Ok(p);
    }

    [HttpGet("classes")]
    public async Task<IActionResult> MyClasses(CancellationToken ct) => Ok(await _service.GetMyClassesAsync(ct));

    [HttpGet("classes/roster")]
    public async Task<IActionResult> Roster([FromQuery] string className, [FromQuery] string sectionName, CancellationToken ct)
        => Ok(await _service.GetRosterAsync(className, sectionName, ct));

    [HttpGet("homework")]
    public async Task<IActionResult> Homework(CancellationToken ct) => Ok(await _service.GetHomeworkAsync(ct));

    [HttpPost("homework")]
    public async Task<IActionResult> CreateHomework([FromBody] CreateHomeworkDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateHomeworkAsync(dto, ct) });

    // ---- attendance ----
    [HttpGet("attendance")]
    public async Task<IActionResult> GetAttendance([FromQuery] string className, [FromQuery] string sectionName, [FromQuery] DateTime date, CancellationToken ct)
        => Ok(await _service.GetAttendanceAsync(className, sectionName, date, ct));

    [HttpPost("attendance")]
    public async Task<IActionResult> SaveAttendance([FromBody] SaveAttendanceDto dto, CancellationToken ct)
    {
        await _service.SaveAttendanceAsync(dto, ct);
        return NoContent();
    }

    // ---- marks ----
    [HttpGet("exams")]
    public async Task<IActionResult> Exams(CancellationToken ct) => Ok(await _service.GetExamsAsync(ct));

    [HttpGet("marks")]
    public async Task<IActionResult> GetMarks([FromQuery] long examId, [FromQuery] string className, [FromQuery] string sectionName, [FromQuery] string subject, CancellationToken ct)
        => Ok(await _service.GetMarksAsync(examId, className, sectionName, subject, ct));

    [HttpPost("marks")]
    public async Task<IActionResult> SaveMarks([FromBody] SaveMarksDto dto, CancellationToken ct)
    {
        await _service.SaveMarksAsync(dto, ct);
        return NoContent();
    }

    // ---- timetable ----
    [HttpGet("timetable")]
    public async Task<IActionResult> Timetable(CancellationToken ct) => Ok(await _service.GetTimetableAsync(ct));
}
