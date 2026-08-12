namespace SchoolErp.Domain.Entities;

/// <summary>A school's active/past subscription. Maps to `school_subscriptions`.</summary>
public class SchoolSubscription
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long PlanId { get; set; }
    public string BillingCycle { get; set; } = "yearly";  // monthly | yearly
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public decimal Price { get; set; }
    public string Status { get; set; } = "trial";  // trial | active | past_due | cancelled | expired
    public bool AutoRenew { get; set; } = true;
    public DateTime? CancelledAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Joined display fields (not columns)
    public string? SchoolName { get; set; }
    public string? PlanName { get; set; }
}
