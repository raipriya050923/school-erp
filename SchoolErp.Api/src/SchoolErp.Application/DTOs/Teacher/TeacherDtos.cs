namespace SchoolErp.Application.DTOs.Teacher;

/// <summary>
/// A section this teacher may enter marks for, and which subjects of it. Driven by
/// teacher_assignments, so it covers every section they teach — not only the one they are
/// class teacher of — and excludes subjects another teacher holds.
/// </summary>
public record TeachingSectionDto(string ClassName, string SectionName, int StudentCount, IReadOnlyList<string> Subjects);

public record TeacherProfileDto(
    long Id, string EmployeeCode, string Name, string? Subject,
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

/* ---- class teacher's review of their own section ---- */

/// <summary>One student's line of the class result: every subject, the total and a grade.</summary>
public record ClassResultStudentDto(
    long StudentId, string? RollNo, string Name,
    IReadOnlyDictionary<string, decimal?> Marks,
    decimal Total, decimal FullTotal, decimal Percent, string Grade,
    /// <summary>Papers with no mark recorded for this student yet.</summary>
    int Missing,
    /// <summary>
    /// False while a paper is unmarked. The percentage is real either way — it is always scored
    /// over the full paper total — but it can only rise as the remaining marks arrive, so the UI
    /// shows it as provisional rather than final.
    /// </summary>
    bool IsComplete);

/// <summary>A paper of the exam, with how much of it is filled in.</summary>
public record ClassResultSubjectDto(string Subject, int FullMarks, int Entered, int Total, string? TeacherName);

/// <summary>
/// The whole section's marks for one exam, read-only. Visible to the section's class teacher so
/// they can review before the admin publishes; subject teachers still own their own entry.
/// </summary>
public record ClassResultDto(
    long ExamId, string ExamName, string ExamStatus, bool IsPublished,
    string ClassName, string SectionName,
    IReadOnlyList<ClassResultSubjectDto> Subjects,
    IReadOnlyList<ClassResultStudentDto> Students,
    /// <summary>Marks still missing across the section — what stops it being ready to publish.</summary>
    int MissingMarks,
    /// <summary>pending | approved — whether the class teacher has signed this sheet off.</summary>
    string ApprovalStatus,
    string? ApprovedByName,
    DateTime? ApprovedAt,
    string? ApprovalRemarks,
    /// <summary>True once every student has every paper marked; approval is refused before that.</summary>
    bool CanApprove);

/// <summary>A class teacher signing off, or withdrawing, their section's result sheet.</summary>
public class ApproveResultDto
{
    public long ExamId { get; set; }
    public string ClassName { get; set; } = "";
    public string SectionName { get; set; } = "";
    /// <summary>False withdraws an approval, putting the sheet back to pending.</summary>
    public bool Approve { get; set; } = true;
    public string? Remarks { get; set; }
}

/// <summary>A section this teacher is class teacher of, and the exams available to review.</summary>
public record MyClassSectionDto(string ClassName, string SectionName, int StudentCount);
