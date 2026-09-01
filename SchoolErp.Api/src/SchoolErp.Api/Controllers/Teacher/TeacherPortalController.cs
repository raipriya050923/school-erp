using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Teacher;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Teacher;

[ApiController]
[Route("api/teacher")]
[Authorize(Roles = "teacher")]
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

    /// <summary>
    /// Sections this teacher may enter marks for, and which subjects of each. Comes from their
    /// subject assignments, so it includes sections they teach but are not class teacher of.
    /// </summary>
    [HttpGet("marks/sections")]
    public async Task<IActionResult> TeachingSections(CancellationToken ct) => Ok(await _service.GetTeachingSectionsAsync(ct));

    /// <summary>Every subject against every student, for entering a whole exam in one pass.</summary>
    [HttpGet("marks/grid")]
    public async Task<IActionResult> MarksGrid([FromQuery] long examId, [FromQuery] string className, [FromQuery] string sectionName, CancellationToken ct)
        => Ok(await _service.GetMarksGridAsync(examId, className, sectionName, ct));

    [HttpPost("marks/grid")]
    public async Task<IActionResult> SaveMarksGrid([FromBody] SaveMarksGridDto dto, CancellationToken ct)
        => Ok(new { saved = await _service.SaveMarksGridAsync(dto, ct) });

    /// <summary>Sections this teacher is class teacher of — the ones whose results they may review.</summary>
    [HttpGet("results/sections")]
    public async Task<IActionResult> MyClassSections(CancellationToken ct) => Ok(await _service.GetMyClassSectionsAsync(ct));

    /// <summary>
    /// The section's full result sheet for one exam, read-only: every subject, not just this
    /// teacher's. Restricted to the section's class teacher. Publishing stays with the admin.
    /// </summary>
    [HttpGet("results/class")]
    public async Task<IActionResult> ClassResult([FromQuery] long examId, [FromQuery] string className, [FromQuery] string sectionName, CancellationToken ct)
        => Ok(await _service.GetClassResultAsync(examId, className, sectionName, ct));

    /// <summary>
    /// The class teacher signs their section's result sheet off, or withdraws it. An admin can
    /// only publish an exam once every section that sat it is approved.
    /// </summary>
    [HttpPost("results/approve")]
    public async Task<IActionResult> ApproveResult([FromBody] ApproveResultDto dto, CancellationToken ct)
    {
        await _service.ApproveResultAsync(dto, ct);
        return NoContent();
    }

    /// <summary>Which papers this exam has for the class, and how many marks are already in.</summary>
    [HttpGet("marks/progress")]
    public async Task<IActionResult> MarksProgress([FromQuery] long examId, [FromQuery] string className, [FromQuery] string sectionName, CancellationToken ct)
        => Ok(await _service.GetMarksProgressAsync(examId, className, sectionName, ct));

    [HttpPost("marks")]
    public async Task<IActionResult> SaveMarks([FromBody] SaveMarksDto dto, CancellationToken ct)
    {
        await _service.SaveMarksAsync(dto, ct);
        return NoContent();
    }

    // ---- timetable ----
    /// <summary>Leave types this school offers, for the apply form.</summary>
    [HttpGet("leave/types")]
    public async Task<IActionResult> LeaveTypes([FromServices] ILeaveService leave, CancellationToken ct)
        => Ok(await leave.TypesAsync(ct));

    /// <summary>The signed-in teacher's own leave requests.</summary>
    [HttpGet("leave")]
    public async Task<IActionResult> MyLeave([FromServices] ILeaveService leave, CancellationToken ct)
        => Ok(await leave.MineAsync(ct));

    [HttpPost("leave")]
    public async Task<IActionResult> ApplyLeave([FromServices] ILeaveService leave,
        [FromBody] ApplyLeaveDto dto, CancellationToken ct)
        => Ok(new { id = await leave.ApplyAsync(dto, ct) });

    [HttpGet("timetable")]
    public async Task<IActionResult> Timetable(CancellationToken ct) => Ok(await _service.GetTimetableAsync(ct));
}
