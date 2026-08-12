using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Billing;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/super-admin/billing")]
public class BillingController : ControllerBase
{
    private readonly IBillingService _service;
    public BillingController(IBillingService service) => _service = service;

    [HttpGet("invoices")]
    public async Task<IActionResult> Invoices([FromQuery] string? status, CancellationToken ct)
        => Ok(await _service.ListInvoicesAsync(status, ct));

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(CancellationToken ct)
        => Ok(await _service.GetSummaryAsync(ct));

    /// <summary>Record a payment against a platform invoice.</summary>
    [HttpPost("invoices/{id:long}/payments")]
    public async Task<IActionResult> RecordPayment(long id, [FromBody] RecordPaymentDto dto, CancellationToken ct)
    {
        await _service.RecordPaymentAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>Email a payment reminder to the school.</summary>
    [HttpPost("invoices/{id:long}/reminder")]
    public async Task<IActionResult> SendReminder(long id, CancellationToken ct)
    {
        await _service.SendReminderAsync(id, ct);
        return NoContent();
    }
}
