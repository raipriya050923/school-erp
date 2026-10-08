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

    /// <summary>Every payment taken against one invoice, oldest first — one receipt each.</summary>
    [HttpGet("invoices/{id:long}/payments")]
    public async Task<IActionResult> Payments(long id, CancellationToken ct)
        => Ok(await _service.PaymentsAsync(id, ct));

    /// <summary>The receipt for one payment, ready to print.</summary>
    [HttpGet("payments/{id:long}/receipt")]
    public async Task<IActionResult> Receipt(long id, CancellationToken ct)
    {
        var receipt = await _service.ReceiptAsync(id, ct);
        return receipt is null ? NotFound() : Ok(receipt);
    }

    [HttpPost("invoices/{id:long}/payments")]
    public async Task<IActionResult> RecordPayment(long id, [FromBody] RecordFeePaymentDto dto, CancellationToken ct)
    {
        await _service.RecordPaymentAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>
    /// Payments families have declared and the office has not yet matched. Pending first, and
    /// oldest first within that, so the longest wait is dealt with before the newest.
    /// </summary>
    [HttpGet("submissions")]
    public async Task<IActionResult> Submissions([FromQuery] string? status, CancellationToken ct)
        => Ok(await _service.ListSubmissionsAsync(status, ct));

    /// <summary>Confirms or turns down one declared payment.</summary>
    [HttpPost("submissions/{id:long}/review")]
    public async Task<IActionResult> ReviewSubmission(long id, [FromBody] ReviewFeeSubmissionDto dto,
        CancellationToken ct)
    {
        await _service.ReviewSubmissionAsync(id, dto, ct);
        return NoContent();
    }

    [HttpPost("generate")]
    public async Task<IActionResult> Generate([FromBody] GenerateInvoicesDto dto, CancellationToken ct)
        => Ok(await _service.GenerateAsync(dto, ct));
}
