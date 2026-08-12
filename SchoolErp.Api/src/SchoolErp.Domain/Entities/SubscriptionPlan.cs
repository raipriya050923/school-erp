namespace SchoolErp.Domain.Entities;

/// <summary>A subscription plan offered to schools. Maps to `subscription_plans`.</summary>
public class SubscriptionPlan
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal PriceMonthly { get; set; }
    public decimal PriceYearly { get; set; }
    public int? MaxStudents { get; set; }     // null = unlimited
    public int? MaxStaff { get; set; }
    public int? MaxStorageMb { get; set; }
    public int TrialDays { get; set; } = 14;
    public bool IsActive { get; set; } = true;
    public int SortOrder { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
