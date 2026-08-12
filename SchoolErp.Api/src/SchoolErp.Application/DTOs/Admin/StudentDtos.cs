namespace SchoolErp.Application.DTOs.Admin;

public record StudentListItemDto(
    long Id, string AdmissionNo, string Name, string? ClassName, string? SectionName,
    string? RollNo, string? GuardianName, string? GuardianPhone, decimal FeeDue, string Status,
    DateTime? AdmissionDate);

public record StudentDetailDto(
    long Id, string AdmissionNo, string Name, string FirstName, string LastName,
    string? ClassName, string? SectionName, string? RollNo, string? Gender, DateTime? Dob,
    string? BloodGroup, string? Email, string? Phone, string? GuardianName, string? GuardianPhone,
    string? Address, string? City, string? State, string? Pincode, string? PreviousSchool,
    DateTime? AdmissionDate, decimal FeeDue, string Status);

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
}
