namespace SchoolErp.Domain.Entities;

/// <summary>A SaaS invoice billed to a school. Maps to `platform_invoices`.</summary>
public class PlatformInvoice
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long SubscriptionId { get; set; }
    public string InvoiceNo { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal TotalAmount { get; set; }
    public DateTime DueDate { get; set; }
    public string Status { get; set; } = "draft";  // draft | sent | paid | overdue | void
    public DateTime? IssuedAt { get; set; }
    public DateTime? PaidAt { get; set; }
    public DateTime? RemindedAt { get; set; }
    public DateTime CreatedAt { get; set; }

    public string? SchoolName { get; set; }
}
