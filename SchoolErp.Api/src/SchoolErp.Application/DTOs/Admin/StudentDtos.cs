using SchoolErp.Application.DTOs.Auth;

namespace SchoolErp.Application.DTOs.Admin;

/// <summary>
/// Result of admitting a student: the student row plus the login that was created for them.
/// The password inside <paramref name="Credentials"/> is shown once and never retrievable again.
/// </summary>
public record CreateStudentResultDto(long Id, string AdmissionNo, string? RollNo, GeneratedCredentialsDto Credentials);

/// <summary>
/// One page of a list, with enough about the whole result for a pager to be drawn: a client
/// cannot work out the last page number from the rows it was handed.
/// </summary>
public record PagedDto<T>(IReadOnlyList<T> Items, int Page, int PageSize, int Total, int TotalPages);

public record StudentListItemDto(
    long Id, string AdmissionNo, string Name, string? ClassName, string? SectionName,
    string? RollNo, string? GuardianName, string? GuardianPhone, decimal FeeDue, string Status,
    DateTime? AdmissionDate);

public record StudentDetailDto(
    long Id, string AdmissionNo, string Name, string FirstName, string LastName,
    string? ClassName, string? SectionName, string? RollNo, string? Gender, DateTime? Dob,
    string? BloodGroup, string? Email, string? Phone, string? GuardianName, string? GuardianPhone,
    string? Address, string? City, string? State, string? Pincode,
    /// <summary>Transfer certificate number from the school the student left.</summary>
    string? TcNo,
    string? PreviousSchool,
    DateTime? AdmissionDate, decimal FeeDue, string Status,
    long? StateId, long? CityId);

public class SaveStudentDto
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? ClassName { get; set; }
    public string? SectionName { get; set; }
    public string? RollNo { get; set; }
    public string? Gender { get; set; }
    public DateTime? Dob { get; set; }
    public string? BloodGroup { get; set; }
    public string? Email { get; set; }
    public string? GuardianName { get; set; }
    public string? GuardianPhone { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Pincode { get; set; }
    public string? PreviousSchool { get; set; }
    /// <summary>Transfer certificate number from the school the student left. Optional.</summary>
    public string? TcNo { get; set; }

    /// <summary>
    /// Geography master ids. Authoritative — the city/state text is written from
    /// whatever they resolve to. The country follows the school, so it is not sent.
    /// </summary>
    public long? StateId { get; set; }
    public long? CityId { get; set; }
}

/* -------- parent logins -------- */

/// <summary>
/// The parent account attached to a student, as the admin console sees it.
/// <c>Username</c> is null when a guardian is recorded as a contact but has
/// never been issued a login.
/// </summary>
public record ParentAccountDto(
    long GuardianId, string Name, string Relation, string Phone, string? Email,
    string? Username, bool HasLogin);

/// <summary>
/// Creates a parent login for a student. The name and phone default to the
/// guardian already recorded on the student, so the common case is one click.
/// </summary>
public class CreateParentLoginDto
{
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    /// <summary>father | mother | guardian | other</summary>
    public string Relation { get; set; } = "guardian";
    public string? Phone { get; set; }
    public string? Email { get; set; }
}
