using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Billing;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

/// <summary>
/// Turns a payment into the receipt a family can keep.
///
/// Shared by the admin console and the student portal deliberately: a receipt the office prints
/// and a receipt the parent prints have to be the same document, down to the receipt number, or
/// the two will be produced against each other in an argument about what was paid. The only
/// difference between the callers is who is allowed to ask.
/// </summary>
public class FeeReceiptBuilder
{
    private readonly IFeeRepository _fees;
    private readonly ISchoolRepository _schools;

    public FeeReceiptBuilder(IFeeRepository fees, ISchoolRepository schools)
    {
        _fees = fees;
        _schools = schools;
    }

    /// <summary>
    /// Builds the receipt, or returns null when the payment does not belong to this school.
    /// <paramref name="onlyForStudentId"/> narrows it further for the student portal, so a
    /// learner cannot print somebody else's receipt by changing the id in the URL.
    /// </summary>
    public async Task<FeeReceiptDto?> BuildAsync(long schoolId, long paymentId,
        long? onlyForStudentId = null, CancellationToken ct = default)
    {
        var payment = await _fees.GetPaymentAsync(schoolId, paymentId, ct);
        if (payment is null) return null;
        if (onlyForStudentId is { } studentId && payment.StudentId != studentId) return null;

        var school = await _schools.GetByIdAsync(schoolId, ct);
        var lines = await _fees.GetInvoiceLinesAsync(schoolId, payment.InvoiceId, ct);

        return new FeeReceiptDto(
            SchoolName: school?.Name ?? "",
            SchoolAddress: AddressOf(school),
            SchoolPhone: string.IsNullOrWhiteSpace(school?.Phone) ? null : school!.Phone,
            SchoolEmail: string.IsNullOrWhiteSpace(school?.Email) ? null : school!.Email,

            PaymentId: payment.Id,
            ReceiptNo: ReceiptNo(payment),
            PaidDate: payment.PaidDate,
            IssuedAt: DateTime.UtcNow,

            StudentName: payment.StudentName ?? "",
            AdmissionNo: payment.AdmissionNo,
            ClassLabel: payment.ClassLabel,

            InvoiceNo: payment.InvoiceNo,
            Month: payment.Month,
            Lines: lines.Select(l => new ReceiptLineDto(l.Description, l.Amount)).ToList(),

            AmountPaid: payment.Amount,
            AmountInWords: AmountInWords.Rupees(payment.Amount),
            Method: payment.Method,
            Reference: payment.Reference,

            InvoiceTotal: payment.InvoiceTotal,
            PaidToDate: payment.PaidToDate,
            // Never shown as a negative: an overpayment is a credit to sort out at the counter,
            // and "-250" on a receipt reads as the school owing money it does not think it owes.
            BalanceAfter: Math.Max(0m, payment.InvoiceTotal - payment.PaidToDate));
    }

    /// <summary>
    /// Derived from the payment id rather than stored, so a receipt reprinted next year carries
    /// the same number as the one handed over on the day. A stored column would be the tidier
    /// answer, but it would also need backfilling for every payment already taken.
    /// </summary>
    private static string ReceiptNo(FeePaymentRow p)
    {
        var year = (p.PaidDate ?? p.CreatedAt).ToString("yy");
        return $"RCPT-{year}-{p.Id:D5}";
    }

    private static string? AddressOf(School? s)
    {
        if (s is null) return null;
        var parts = new[] { s.Address, s.City, s.State, s.PostalCode }
            .Where(x => !string.IsNullOrWhiteSpace(x));
        var joined = string.Join(", ", parts);
        return joined.Length == 0 ? null : joined;
    }
}
