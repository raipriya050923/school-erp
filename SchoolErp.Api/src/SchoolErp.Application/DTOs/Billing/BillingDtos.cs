namespace SchoolErp.Application.DTOs.Billing;

public record InvoiceDto(
    long Id,
    string InvoiceNo,
    long SchoolId,
    string SchoolName,
    decimal TotalAmount,
    DateTime? IssuedAt,
    DateTime DueDate,
    string Status,
    DateTime? PaidAt,
    DateTime? RemindedAt);

public record BillingSummaryDto(
    decimal Collected,
    decimal Outstanding,
    decimal Overdue,
    int PaidCount,
    int SentCount,
    int OverdueCount);

public class RecordPaymentDto
{
    public decimal Amount { get; set; }
    public string Method { get; set; } = "bank_transfer";
    public string? TransactionRef { get; set; }
    public DateTime PaidAt { get; set; } = DateTime.UtcNow;
    public string? Remarks { get; set; }
}
