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
    /// <summary>
    /// The shell palette every portal of this school renders in: classic | brand | forest | mist.
    /// A name rather than a colour — each is a designed set whose parts have to stay in step.
    /// </summary>
    public string Theme { get; set; } = "classic";
    public string Email { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    /// <summary>
    /// Street address — the part of the address no master can supply. Maps to the
    /// `address_line1` column; `address_line2` is left unused, as one line is all the
    /// onboarding form collects.
    /// </summary>
    public string? Address { get; set; }
    // Free-text address, kept in step with the ids below. The ids are authoritative;
    // these remain because pre-master rows hold values that match no master entry.
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Country { get; set; }
    public string? PostalCode { get; set; }

    // Geography master (platform-level). Null on schools onboarded before it existed.
    public long? CountryId { get; set; }
    public long? StateId { get; set; }
    public long? CityId { get; set; }
    public string Timezone { get; set; } = "Asia/Kathmandu";
    /// <summary>Days the school runs, as day-of-week numbers (1 = Sunday … 7 = Saturday).</summary>
    public string WorkingDays { get; set; } = "1,2,3,4,5,6";
    public string Currency { get; set; } = "NPR";
    public string? AffiliationBoard { get; set; }
    public string Status { get; set; } = "pending";   // pending | active | suspended | terminated
    public DateTime? OnboardedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
