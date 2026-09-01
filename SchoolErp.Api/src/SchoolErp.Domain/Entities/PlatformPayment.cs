namespace SchoolErp.Domain.Entities;

/// <summary>A payment recorded against a platform invoice. Maps to `platform_payments`.</summary>
public class PlatformPayment
{
    public long Id { get; set; }
    public long InvoiceId { get; set; }
    public long SchoolId { get; set; }
    public decimal Amount { get; set; }
    public string Method { get; set; } = string.Empty;  // bank_transfer | upi | debit_card | credit_card | cash | …
    /// <summary>Only meaningful for a bank transfer; null for every other method.</summary>
    public string? BankName { get; set; }
    public string? TransactionRef { get; set; }
    /// <summary>Relative path to an uploaded payment screenshot, e.g. /uploads/payments/xyz.png.</summary>
    public string? ProofUrl { get; set; }
    public string Status { get; set; } = "success";      // pending | success | failed | refunded
    public DateTime? PaidAt { get; set; }
    public string? Remarks { get; set; }
    public DateTime CreatedAt { get; set; }
}
