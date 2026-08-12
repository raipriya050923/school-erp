namespace SchoolErp.Application.DTOs.Plans;

public record PlanDto(
    long Id,
    string Name,
    string Slug,
    string? Description,
    decimal PriceMonthly,
    decimal PriceYearly,
    int? MaxStudents,
    int? MaxStaff,
    int TrialDays,
    bool IsActive,
    int SubscriberCount);

public class CreatePlanDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal PriceMonthly { get; set; }
    public decimal PriceYearly { get; set; }
    public int? MaxStudents { get; set; }
    public int? MaxStaff { get; set; }
    public int TrialDays { get; set; } = 14;
}

public class UpdatePlanDto
{
    public string? Description { get; set; }
    public decimal PriceMonthly { get; set; }
    public decimal PriceYearly { get; set; }
    public int? MaxStudents { get; set; }
    public int? MaxStaff { get; set; }
    public int TrialDays { get; set; } = 14;
}
