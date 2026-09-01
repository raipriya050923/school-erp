using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Billing;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/super-admin/billing")]
[Authorize(Roles = "super_admin")]
public class BillingController : ControllerBase
{
    private const long MaxProofBytes = 5 * 1024 * 1024;
    private static readonly string[] AllowedProofTypes = { ".png", ".jpg", ".jpeg", ".webp", ".pdf" };

    private readonly IBillingService _service;
    private readonly IWebHostEnvironment _env;

    public BillingController(IBillingService service, IWebHostEnvironment env)
    {
        _service = service;
        _env = env;
    }

    [HttpGet("invoices")]
    public async Task<IActionResult> Invoices([FromQuery] string? status, CancellationToken ct)
        => Ok(await _service.ListInvoicesAsync(status, ct));

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(CancellationToken ct)
        => Ok(await _service.GetSummaryAsync(ct));

    /// <summary>Raise an invoice against a school's current subscription.</summary>
    [HttpPost("invoices")]
    public async Task<IActionResult> Raise([FromBody] RaiseInvoiceDto dto, CancellationToken ct)
        => Ok(await _service.RaiseInvoiceAsync(dto, ct));

    /// <summary>
    /// Stores a payment screenshot and returns the path to attach to the payment.
    /// Images and PDFs only, 5 MB cap; the file is renamed to a random GUID so a caller can
    /// never choose the path it lands on or the extension it is served with.
    /// </summary>
    [HttpPost("payment-proof")]
    [RequestSizeLimit(MaxProofBytes)]
    public async Task<IActionResult> UploadProof(IFormFile file, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            return BadRequest(new { message = "Choose a file to upload." });
        if (file.Length > MaxProofBytes)
            return BadRequest(new { message = "The file is larger than 5 MB." });

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedProofTypes.Contains(ext))
            return BadRequest(new { message = "Upload a PNG, JPG, WEBP or PDF file." });

        var folder = Path.Combine(_env.ContentRootPath, "wwwroot", "uploads", "payments");
        Directory.CreateDirectory(folder);
        var name = $"{Guid.NewGuid():N}{ext}";
        await using (var stream = System.IO.File.Create(Path.Combine(folder, name)))
            await file.CopyToAsync(stream, ct);

        return Ok(new { url = $"/uploads/payments/{name}", fileName = file.FileName });
    }

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
