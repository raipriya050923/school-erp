namespace SchoolErp.Application.DTOs.Teacher;

public record TeacherProfileDto(
    long Id, string EmployeeCode, string Name, string? Subject, string? ClassesTaught,
    string? Phone, string? Email, string? Qualification, DateTime? JoiningDate);

public record MyClassDto(
    long SectionId, string ClassName, string SectionName, string? Subject,
    string? Room, int StudentCount, bool IsClassTeacher);

public record RosterStudentDto(long Id, string? RollNo, string Name);

public record HomeworkDto(
    long Id, string Title, string? Subject, string? ClassLabel,
    DateTime? AssignedDate, DateTime? DueDate, int Submitted, int Total, string Status);

public class CreateHomeworkDto
{
    public string Title { get; set; } = string.Empty;
    public string? Subject { get; set; }
    public string? ClassLabel { get; set; }
    public DateTime? DueDate { get; set; }
    public int TotalCount { get; set; }
}

public record TeacherDashboardDto(
    TeacherProfileDto Profile,
    int MyClassesCount,
    int StudentsTaught,
    int SubmissionsToGrade,
    int OpenHomework,
    IReadOnlyList<HomeworkDto> RecentHomework);
