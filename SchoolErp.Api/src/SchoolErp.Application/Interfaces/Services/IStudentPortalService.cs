using SchoolErp.Application.DTOs.Billing;
using SchoolErp.Application.DTOs.Student;

namespace SchoolErp.Application.Interfaces.Services;

public interface IStudentPortalService
{
    Task<StudentDashboardDto> GetDashboardAsync(CancellationToken ct = default);
    Task<StudentProfileDto?> GetProfileAsync(CancellationToken ct = default);
    Task<StudentAttendanceDto> GetAttendanceAsync(CancellationToken ct = default);
    Task<StudentTimetableDto> GetTimetableAsync(CancellationToken ct = default);
    Task<IReadOnlyList<StudentHomeworkDto>> GetHomeworkAsync(CancellationToken ct = default);
    Task<StudentExamsDto> GetExamsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<StudentFeeDto>> GetFeesAsync(CancellationToken ct = default);
    /// <summary>Payments confirmed against one of this student's invoices — one receipt each.</summary>
    Task<IReadOnlyList<FeePaymentDto>> GetInvoicePaymentsAsync(long invoiceId, CancellationToken ct = default);
    /// <summary>
    /// The receipt for one payment, or null when it is not this student's. Checked against the
    /// signed student id rather than the invoice in the URL, so changing the number in the
    /// address bar reaches nobody else's receipt.
    /// </summary>
    Task<FeeReceiptDto?> GetReceiptAsync(long paymentId, CancellationToken ct = default);
    /// <summary>
    /// Declares a payment against one invoice. Nothing is owed any differently until the school
    /// verifies it — this only queues the claim.
    /// </summary>
    Task<long> SubmitFeePaymentAsync(long invoiceId, SubmitFeePaymentDto dto, CancellationToken ct = default);
    /// <summary>What this student has submitted and what became of it.</summary>
    Task<IReadOnlyList<StudentFeeSubmissionDto>> GetFeeSubmissionsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<StudentNoticeDto>> GetNoticesAsync(CancellationToken ct = default);
}
