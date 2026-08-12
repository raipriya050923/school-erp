namespace SchoolErp.Domain.Entities;

/// <summary>A payment recorded against a platform invoice. Maps to `platform_payments`.</summary>
public class PlatformPayment
{
    public long Id { get; set; }
    public long InvoiceId { get; set; }
    public long SchoolId { get; set; }
    public decimal Amount { get; set; }
    public string Method { get; set; } = string.Empty;  // card | bank_transfer | esewa | khalti | stripe | cash | other
    public string? TransactionRef { get; set; }
    public string Status { get; set; } = "success";      // pending | success | failed | refunded
    public DateTime? PaidAt { get; set; }
    public string? Remarks { get; set; }
    public DateTime CreatedAt { get; set; }
}
