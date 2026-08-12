using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Student;

[ApiController]
[Route("api/student")]
public class StudentPortalController : ControllerBase
{
    private readonly IStudentPortalService _service;
    public StudentPortalController(IStudentPortalService service) => _service = service;

    [HttpGet("dashboard/stats")]
    public async Task<IActionResult> Dashboard(CancellationToken ct) => Ok(await _service.GetDashboardAsync(ct));

    [HttpGet("profile")]
    public async Task<IActionResult> Profile(CancellationToken ct)
    {
        var p = await _service.GetProfileAsync(ct);
        return p is null ? NotFound() : Ok(p);
    }

    [HttpGet("attendance")]
    public async Task<IActionResult> Attendance(CancellationToken ct) => Ok(await _service.GetAttendanceAsync(ct));

    [HttpGet("timetable")]
    public async Task<IActionResult> Timetable(CancellationToken ct) => Ok(await _service.GetTimetableAsync(ct));

    [HttpGet("homework")]
    public async Task<IActionResult> Homework(CancellationToken ct) => Ok(await _service.GetHomeworkAsync(ct));

    [HttpGet("exams")]
    public async Task<IActionResult> Exams(CancellationToken ct) => Ok(await _service.GetExamsAsync(ct));

    [HttpGet("fees")]
    public async Task<IActionResult> Fees(CancellationToken ct) => Ok(await _service.GetFeesAsync(ct));

    [HttpGet("notices")]
    public async Task<IActionResult> Notices(CancellationToken ct) => Ok(await _service.GetNoticesAsync(ct));
}
