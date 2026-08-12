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
    DateTime CreatedAt);

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
}

public record UpdateStatusDto(string Status);
