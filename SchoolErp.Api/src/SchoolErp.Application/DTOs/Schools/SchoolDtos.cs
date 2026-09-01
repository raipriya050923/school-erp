namespace SchoolErp.Application.DTOs.Schools;

public record SchoolListItemDto(
    long Id,
    string SchoolCode,
    string Name,
    string? City,
    string Status,
    string? PlanName,
    int StudentCount,
    DateTime CreatedAt);

public record SchoolDetailDto(
    long Id,
    string SchoolCode,
    string Name,
    string Subdomain,
    string Email,
    string Phone,
    string? City,
    string? State,
    string? Country,
    string? PostalCode,
    string? AffiliationBoard,
    string Currency,
    string Timezone,
    string Status,
    DateTime? OnboardedAt,
    DateTime CreatedAt,
    // Current subscription, or nulls when the school has never had one.
    long? PlanId,
    string? PlanName,
    string? BillingCycle,
    string? SubscriptionStatus,
    DateTime? SubscriptionEndsOn,
    // The school's admin login. AdminPassword is only ever non-null when a demo password is
    // configured (Accounts:FixedPassword) — real passwords are bcrypt-hashed and unreadable,
    // so the only way to learn one otherwise is to reset it.
    string? AdminUsername,
    string? AdminEmail,
    string? AdminPassword,
    // Geography master ids, for preselecting the cascading pickers.
    long? CountryId,
    long? StateId,
    long? CityId);

/// <summary>
/// Returned once, immediately after onboarding. <see cref="TemporaryPassword"/> is the only
/// time the plaintext exists outside the super admin's screen — only the bcrypt hash is stored,
/// so it cannot be read back later. Until credentials are emailed automatically, the super
/// admin is expected to copy these from the confirmation dialog.
/// </summary>
public record CreateSchoolResultDto(
    long SchoolId,
    string SchoolName,
    string SchoolCode,
    string Subdomain,
    string AdminFullName,
    string Username,
    string Email,
    string TemporaryPassword,
    string PlanName,
    string SubscriptionStatus,
    DateTime SubscriptionEndsOn);

public class CreateSchoolDto
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Country { get; set; } = "Nepal";
    public string? PostalCode { get; set; }
    public string? AffiliationBoard { get; set; }
    public string Status { get; set; } = "pending";

    /// <summary>Plan the school subscribes to. Required — a school with no subscription is
    /// invisible to the Subscriptions page and to revenue reporting.</summary>
    public long PlanId { get; set; }
    public string BillingCycle { get; set; } = "yearly";   // monthly | yearly

    /// <summary>
    /// Geography master ids. These are authoritative — the city/state/country text
    /// columns are written from whatever they resolve to.
    /// </summary>
    public long? CountryId { get; set; }
    public long? StateId { get; set; }
    public long? CityId { get; set; }
}

public class UpdateSchoolDto
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Country { get; set; }
    public string? PostalCode { get; set; }
    public string? AffiliationBoard { get; set; }
    public string Status { get; set; } = "active";

    /// <summary>Plan to move the school onto. 0 leaves the existing subscription untouched.</summary>
    public long PlanId { get; set; }
    public string BillingCycle { get; set; } = "yearly";

    /// <summary>
    /// Geography master ids. These are authoritative — the city/state/country text
    /// columns are written from whatever they resolve to.
    /// </summary>
    public long? CountryId { get; set; }
    public long? StateId { get; set; }
    public long? CityId { get; set; }
}

public record UpdateStatusDto(string Status);
