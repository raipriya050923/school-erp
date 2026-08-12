namespace SchoolErp.Domain.Entities;

/// <summary>A tenant school on the platform. Maps to the `schools` table.</summary>
public class School
{
    public long Id { get; set; }
    public string SchoolCode { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Subdomain { get; set; } = string.Empty;
    public string? CustomDomain { get; set; }
    public string? LogoUrl { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Country { get; set; }
    public string? PostalCode { get; set; }
    public string Timezone { get; set; } = "Asia/Kathmandu";
    public string Currency { get; set; } = "NPR";
    public string? AffiliationBoard { get; set; }
    public string Status { get; set; } = "pending";   // pending | active | suspended | terminated
    public DateTime? OnboardedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
