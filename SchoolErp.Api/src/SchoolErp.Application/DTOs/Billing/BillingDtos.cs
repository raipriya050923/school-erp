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

/// <summary>Raises an invoice against a school's current subscription.</summary>
public class RaiseInvoiceDto
{
    public long SchoolId { get; set; }
    /// <summary>Defaults to the subscription's locked-in price when left null or zero.</summary>
    public decimal? Amount { get; set; }
    /// <summary>Defaults to 14 days out when left null.</summary>
    public DateTime? DueDate { get; set; }
}

public class RecordPaymentDto
{
    public decimal Amount { get; set; }
    public string Method { get; set; } = "bank_transfer";
    /// <summary>Required when <see cref="Method"/> is bank_transfer; ignored otherwise.</summary>
    public string? BankName { get; set; }
    public string? TransactionRef { get; set; }
    /// <summary>Path returned by the proof upload endpoint.</summary>
    public string? ProofUrl { get; set; }
    public DateTime PaidAt { get; set; } = DateTime.UtcNow;
    public string? Remarks { get; set; }
}
