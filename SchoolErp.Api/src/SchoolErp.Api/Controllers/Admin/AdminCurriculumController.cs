using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

/// <summary>
/// Subjects taught by a class and the teacher responsible for each subject in each section.
/// Complements the class teacher on the section itself: one pastoral owner, many subject teachers.
/// </summary>
[ApiController]
[Route("api/admin/curriculum")]
[Authorize(Roles = "school_admin")]
public class AdminCurriculumController : ControllerBase
{
    private readonly ICurriculumService _service;
    public AdminCurriculumController(ICurriculumService service) => _service = service;

    /// <summary>
    /// Every class with the subjects it studies. The exam screens use it so a paper can only be
    /// scheduled in a subject the class actually takes.
    /// </summary>
    [HttpGet("subjects-by-class")]
    public async Task<IActionResult> SubjectsByClass(CancellationToken ct)
        => Ok(await _service.SubjectsByClassAsync(ct));

    /// <summary>Subject picks plus the teacher grid for one class.</summary>
    [HttpGet("classes/{classId:long}")]
    public async Task<IActionResult> Get(long classId, CancellationToken ct)
        => Ok(await _service.GetAsync(classId, ct));

    /// <summary>Replaces the subjects this class studies.</summary>
    [HttpPut("classes/{classId:long}/subjects")]
    public async Task<IActionResult> SetSubjects(long classId, [FromBody] SetClassSubjectsDto dto, CancellationToken ct)
    {
        await _service.SetSubjectsAsync(classId, dto, ct);
        return NoContent();
    }

    /// <summary>Unassigns every subject teacher for a class.</summary>
    [HttpDelete("classes/{classId:long}/assignments")]
    public async Task<IActionResult> ClearAssignments(long classId, CancellationToken ct)
        => Ok(new { cleared = await _service.ClearAssignmentsAsync(classId, ct) });

    /// <summary>Sets (or clears, with a null staffId) the teacher for one section/subject.</summary>
    [HttpPut("assignments")]
    public async Task<IActionResult> Assign([FromBody] SaveAssignmentDto dto, CancellationToken ct)
    {
        await _service.AssignAsync(dto, ct);
        return NoContent();
    }
}
