using SchoolErp.Application.DTOs.Auth;

namespace SchoolErp.Application.DTOs.Admin;

/// <summary>
/// Result of registering a teacher: the staff row plus the login that was created for them.
/// The password inside <paramref name="Credentials"/> is shown once and never retrievable again.
/// </summary>
public record CreateTeacherResultDto(long Id, string EmployeeCode, GeneratedCredentialsDto Credentials);

public record TeacherListItemDto(
    long Id, string EmployeeCode, string Name, string? Subject,
    string? Phone, string? Email, string Status, DateTime? JoiningDate,
    /// <summary>The section this teacher is class teacher of, or null when they own none.</summary>
    string? ClassTeacherOf);

public record TeacherDetailDto(
    long Id, string EmployeeCode, string Name, string FirstName, string LastName,
    string? Subject, string? Phone, string? Email, string? Qualification,
    string? Gender, DateTime? Dob, string? Address, string? City, string? State, string? Pincode,
    DateTime? JoiningDate, string Status,
    long? StateId, long? CityId,
    /// <summary>Each qualification separately; `Qualification` above is the joined summary.</summary>
    IReadOnlyList<QualificationDto> Qualifications);

/// <summary>
/// One qualification a teacher holds. <paramref name="Institution"/> is the awarding university
/// or board; both it and <paramref name="CompletionYear"/> are optional.
/// </summary>
public record QualificationDto(string Name, string? Institution, int? CompletionYear);

public class SaveQualificationDto
{
    public string Name { get; set; } = string.Empty;
    public string? Institution { get; set; }
    public int? CompletionYear { get; set; }
}

public class SaveTeacherDto
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Subject { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    /// <summary>Legacy single value; ignored when <see cref="Qualifications"/> is supplied.</summary>
    public string? Qualification { get; set; }
    public List<SaveQualificationDto> Qualifications { get; set; } = new();
    public string? Gender { get; set; }
    public DateTime? Dob { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Pincode { get; set; }

    /// <summary>
    /// Geography master ids. Authoritative — the city/state text is written from
    /// whatever they resolve to. The country follows the school, so it is not sent.
    /// </summary>
    public long? StateId { get; set; }
    public long? CityId { get; set; }
}
