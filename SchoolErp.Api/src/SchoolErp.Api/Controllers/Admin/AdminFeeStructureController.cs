using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

/// <summary>
/// The fee heads a school levies and what each class pays for them. Invoice amounts come from
/// here, so changing a price changes what the next invoice run bills — invoices already raised
/// keep the amounts they were raised with.
/// </summary>
[ApiController]
[Route("api/admin/fee-structure")]
[Authorize(Roles = "school_admin")]
public class AdminFeeStructureController : ControllerBase
{
    private readonly IFeeStructureService _service;
    public AdminFeeStructureController(IFeeStructureService service) => _service = service;

    /// <summary>The pricing grid: classes, heads, and the amounts set for one academic year.</summary>
    [HttpGet]
    public async Task<IActionResult> Grid([FromQuery] long? academicYearId, CancellationToken ct)
        => Ok(await _service.GridAsync(academicYearId, ct));

    [HttpPut]
    public async Task<IActionResult> SaveGrid([FromBody] SaveFeeStructureDto dto, CancellationToken ct)
    {
        await _service.SaveGridAsync(dto, ct);
        return NoContent();
    }

    /// <summary>Carries last year's prices into a new year, leaving anything already priced alone.</summary>
    [HttpPost("copy")]
    public async Task<IActionResult> Copy([FromBody] CopyFeeStructureDto dto, CancellationToken ct)
        => Ok(new { copied = await _service.CopyYearAsync(dto, ct) });

    [HttpGet("heads")]
    public async Task<IActionResult> Heads(CancellationToken ct) => Ok(await _service.ListHeadsAsync(ct));

    [HttpPost("heads")]
    public async Task<IActionResult> CreateHead([FromBody] SaveFeeHeadDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateHeadAsync(dto, ct) });

    [HttpPut("heads/{id:long}")]
    public async Task<IActionResult> UpdateHead(long id, [FromBody] SaveFeeHeadDto dto, CancellationToken ct)
    {
        await _service.UpdateHeadAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>
    /// Retire or restore a head. Retiring stops it appearing on the grid and stops it being
    /// billed, but leaves its prices and the invoice lines that already cite it intact.
    /// </summary>
    [HttpPatch("heads/{id:long}/active")]
    public async Task<IActionResult> SetHeadActive(long id, [FromQuery] bool value, CancellationToken ct)
    {
        await _service.SetHeadActiveAsync(id, value, ct);
        return NoContent();
    }
}
