namespace SchoolErp.Application.DTOs.Admin;

public record TeacherListItemDto(
    long Id, string EmployeeCode, string Name, string? Subject, string? ClassesTaught,
    string? Phone, string? Email, string Status, DateTime? JoiningDate);

public record TeacherDetailDto(
    long Id, string EmployeeCode, string Name, string FirstName, string LastName,
    string? Subject, string? ClassesTaught, string? Phone, string? Email, string? Qualification,
    string? Gender, DateTime? Dob, string? Address, string? City, string? State, string? Pincode,
    DateTime? JoiningDate, string Status);

public class SaveTeacherDto
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Subject { get; set; }
    public string? ClassesTaught { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? Qualification { get; set; }
    public string? Gender { get; set; }
    public DateTime? Dob { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Pincode { get; set; }
}
