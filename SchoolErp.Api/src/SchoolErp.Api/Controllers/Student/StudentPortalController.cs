using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Student;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Student;

[ApiController]
[Route("api/student")]
// Parents read the same endpoints as their child. Access is decided by the
// student_id claim the token carries, not by the role, so a parent can only ever
// see the student they are linked to.
[Authorize(Roles = "student,parent")]
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

    /// <summary>
    /// Declares a payment made outside the system. It is queued for the school to confirm —
    /// nothing about what is owed changes until they do.
    /// </summary>
    [HttpPost("fees/{invoiceId:long}/submit")]
    public async Task<IActionResult> SubmitFeePayment(long invoiceId,
        [FromBody] SubmitFeePaymentDto dto, CancellationToken ct)
        => Ok(new { id = await _service.SubmitFeePaymentAsync(invoiceId, dto, ct) });

    /// <summary>What has been submitted and what the school made of it.</summary>
    /// <summary>Payments confirmed against one of this student's invoices.</summary>
    [HttpGet("fees/{invoiceId:long}/payments")]
    public async Task<IActionResult> InvoicePayments(long invoiceId, CancellationToken ct)
        => Ok(await _service.GetInvoicePaymentsAsync(invoiceId, ct));

    /// <summary>The printable receipt for one of this student's payments.</summary>
    [HttpGet("fees/payments/{paymentId:long}/receipt")]
    public async Task<IActionResult> Receipt(long paymentId, CancellationToken ct)
    {
        var receipt = await _service.GetReceiptAsync(paymentId, ct);
        return receipt is null ? NotFound() : Ok(receipt);
    }

    [HttpGet("fees/submissions")]
    public async Task<IActionResult> FeeSubmissions(CancellationToken ct)
        => Ok(await _service.GetFeeSubmissionsAsync(ct));

    [HttpGet("notices")]
    public async Task<IActionResult> Notices(CancellationToken ct) => Ok(await _service.GetNoticesAsync(ct));
}
