using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

/// <summary>
/// Transport fees, which are priced per student rather than per class: a scale of distance bands
/// for the academic year, and one distance for each child who rides. The invoice run reads both,
/// so a change here changes what the next run bills — invoices already raised keep their lines.
/// </summary>
[ApiController]
[Route("api/admin/transport")]
[Authorize(Roles = "school_admin")]
public class AdminTransportController : ControllerBase
{
    private readonly ITransportService _service;
    public AdminTransportController(ITransportService service) => _service = service;

    /// <summary>The bands for one year, every student, and the amount their distance earns.</summary>
    [HttpGet]
    public async Task<IActionResult> Grid([FromQuery] long? academicYearId, CancellationToken ct)
        => Ok(await _service.GridAsync(academicYearId, ct));

    /// <summary>Replaces the whole band set; bands are only meaningful together.</summary>
    [HttpPut("slabs")]
    public async Task<IActionResult> SaveSlabs([FromBody] SaveTransportSlabsDto dto, CancellationToken ct)
    {
        await _service.SaveSlabsAsync(dto, ct);
        return NoContent();
    }

    /// <summary>Writes transport details for the students named. Everyone else is left alone.</summary>
    [HttpPut("students")]
    public async Task<IActionResult> SaveStudents([FromBody] SaveTransportStudentsDto dto, CancellationToken ct)
        => Ok(new { saved = await _service.SaveStudentsAsync(dto, ct) });

    [HttpPost("copy")]
    public async Task<IActionResult> Copy([FromBody] CopyFeeStructureDto dto, CancellationToken ct)
        => Ok(new { copied = await _service.CopySlabsAsync(dto, ct) });
}
