using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/exams")]
[Authorize(Roles = "school_admin")]
public class AdminExamsController : ControllerBase
{
    private readonly IAdminExamService _service;
    public AdminExamsController(IAdminExamService service) => _service = service;

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] CreateExamDto dto, CancellationToken ct)
    {
        await _service.UpdateExamAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>Deletes the exam, its papers and any marks recorded against it.</summary>
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken ct)
    {
        await _service.DeleteExamAsync(id, ct);
        return NoContent();
    }

    /// <summary>Cancel an exam, or reinstate a cancelled one ("scheduled").</summary>
    /// <summary>
    /// Which sections have been signed off by their class teacher. Publishing waits on all of them.
    /// </summary>
    [HttpGet("{id:long}/approvals")]
    public async Task<IActionResult> Approvals(long id, CancellationToken ct) => Ok(await _service.ApprovalsAsync(id, ct));

    [HttpPatch("{id:long}/status")]
    public async Task<IActionResult> SetStatus(long id, [FromBody] UpdateExamStatusDto dto, CancellationToken ct)
    {
        await _service.SetStatusAsync(id, dto.Status, ct);
        return NoContent();
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await _service.ListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateExamDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateExamAsync(dto, ct) });

    [HttpPost("papers")]
    public async Task<IActionResult> AddPaper([FromBody] SaveExamPaperDto dto, CancellationToken ct)
        => Ok(await _service.AddPaperAsync(dto, ct));

    [HttpDelete("papers/{id:long}")]
    public async Task<IActionResult> DeletePaper(long id, CancellationToken ct)
    {
        await _service.DeletePaperAsync(id, ct);
        return NoContent();
    }
}
