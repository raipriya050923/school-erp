using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/exams")]
public class AdminExamsController : ControllerBase
{
    private readonly IAdminExamService _service;
    public AdminExamsController(IAdminExamService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await _service.ListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateExamDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateExamAsync(dto, ct) });

    [HttpPost("papers")]
    public async Task<IActionResult> AddPaper([FromBody] SaveExamPaperDto dto, CancellationToken ct)
        => Ok(new { id = await _service.AddPaperAsync(dto, ct) });

    [HttpDelete("papers/{id:long}")]
    public async Task<IActionResult> DeletePaper(long id, CancellationToken ct)
    {
        await _service.DeletePaperAsync(id, ct);
        return NoContent();
    }
}
