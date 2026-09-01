using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/fees")]
[Authorize(Roles = "school_admin")]
public class AdminFeesController : ControllerBase
{
    private readonly IAdminFeeService _service;
    public AdminFeesController(IAdminFeeService service) => _service = service;

    [HttpGet("invoices")]
    public async Task<IActionResult> Invoices([FromQuery] string? status, CancellationToken ct)
        => Ok(await _service.ListAsync(status, ct));

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(CancellationToken ct) => Ok(await _service.SummaryAsync(ct));

    /// <summary>The head-by-head breakdown behind an invoice total.</summary>
    [HttpGet("invoices/{id:long}/lines")]
    public async Task<IActionResult> Lines(long id, CancellationToken ct) => Ok(await _service.LinesAsync(id, ct));

    [HttpPost("invoices/{id:long}/payments")]
    public async Task<IActionResult> RecordPayment(long id, [FromBody] RecordFeePaymentDto dto, CancellationToken ct)
    {
        await _service.RecordPaymentAsync(id, dto, ct);
        return NoContent();
    }

    [HttpPost("generate")]
    public async Task<IActionResult> Generate([FromBody] GenerateInvoicesDto dto, CancellationToken ct)
        => Ok(await _service.GenerateAsync(dto, ct));
}
