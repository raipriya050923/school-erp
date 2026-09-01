namespace SchoolErp.Application.DTOs.Transactional;

/* -------- attendance -------- */
public record AttendanceRowDto(long StudentId, string? RollNo, string Name, string Status);

public class SaveAttendanceDto
{
    public string ClassName { get; set; } = string.Empty;
    public string SectionName { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public List<AttendanceEntry> Entries { get; set; } = new();
}
public class AttendanceEntry { public long StudentId { get; set; } public string Status { get; set; } = "present"; }

public record AttendanceDayDto(string Date, string Day, string Status);
public record AttendanceReportDto(
    string StudentName, int Present, int Absent, int Late, int SchoolDays, int Percent,
    IReadOnlyList<AttendanceDayDto> Days);

/* -------- exams -------- */
public record ExamPaperDto(long Id, string? ClassLabel, string Subject, DateTime? ExamDate, string? Time, string? Room, int FullMarks);
/// <summary>
/// <paramref name="Status"/> is what to act on. <paramref name="IsManualStatus"/> says whether an
/// admin pinned it; <paramref name="DerivedStatus"/> is what the dates would pick, so the UI can
/// offer "back to automatic" and show what that would mean.
/// </summary>
public record ExamDto(
    long Id, string Name, string? Type, DateTime? StartDate, DateTime? EndDate, string? Classes,
    string Status, bool IsManualStatus, string DerivedStatus,
    int PaperCount, IReadOnlyList<ExamPaperDto> Papers);
public class CreateExamDto { public string Name { get; set; } = ""; public string? Type { get; set; } public DateTime? StartDate { get; set; } public DateTime? EndDate { get; set; } public string? Classes { get; set; } }
public class SaveExamPaperDto
{
    public long ExamId { get; set; }
    /// <summary>A single class. Ignored when <see cref="ClassLabels"/> is supplied.</summary>
    public string? ClassLabel { get; set; }
    /// <summary>
    /// Schedule the same paper for several classes at once. Classes that already have the
    /// subject are skipped rather than failing the whole request — an admin adding a subject
    /// across the school should not have to remember which classes already sat it.
    /// </summary>
    public List<string> ClassLabels { get; set; } = new();
    public string Subject { get; set; } = "";
    public DateTime? ExamDate { get; set; }
    public string? Time { get; set; }
    public string? Room { get; set; }
    public int FullMarks { get; set; } = 100;
}

/// <summary>What an Add Subject run did, per class.</summary>
public record AddPapersResultDto(int Created, IReadOnlyList<string> Scheduled, IReadOnlyList<string> AlreadyScheduled);
/// <summary>
/// One section's sign-off state for an exam. Publishing is gated on every section being
/// approved, so this is the admin's checklist of who they are waiting on.
/// </summary>
public record ExamApprovalDto(
    string ClassName, string SectionName, string Status,
    string? ApprovedByName, DateTime? ApprovedAt, string? Remarks,
    int StudentCount, int CompleteCount);

/// <summary>"auto" hands control back to the dates; anything else pins the status.</summary>
public record UpdateExamStatusDto(string Status);

/* -------- marks -------- */
public record MarkRowDto(long StudentId, string? RollNo, string Name, decimal? Marks);
public class SaveMarksDto
{
    public long ExamId { get; set; }
    public string ClassName { get; set; } = "";
    public string SectionName { get; set; } = "";
    public string Subject { get; set; } = "";
    public int FullMarks { get; set; } = 100;
    public List<MarkEntry> Entries { get; set; } = new();
}
public class MarkEntry { public long StudentId { get; set; } public decimal? Marks { get; set; } }
/// <summary>
/// One paper of an exam, with how much of the section has been marked. Drives the subject picker
/// on Marks Entry — a teacher works through the papers, not through free-typed subject names.
/// </summary>
public record MarksProgressDto(string Subject, int FullMarks, DateTime? ExamDate, int Entered, int Total);

/// <summary>One column of the marks grid.</summary>
public record MarksGridSubjectDto(string Subject, int FullMarks, DateTime? ExamDate);
/// <summary>
/// One row of the marks grid: a student and their mark for each subject, keyed by subject name.
/// A subject missing from <paramref name="Marks"/> has nothing recorded yet.
/// </summary>
public record MarksGridStudentDto(long StudentId, string? RollNo, string Name, IReadOnlyDictionary<string, decimal?> Marks);
/// <summary>
/// Every subject of an exam against every student of a section, so a teacher can work down one
/// subject or across one student without reloading between each.
/// </summary>
public record MarksGridDto(IReadOnlyList<MarksGridSubjectDto> Subjects, IReadOnlyList<MarksGridStudentDto> Students);

public class SaveMarksGridDto
{
    public long ExamId { get; set; }
    public string ClassName { get; set; } = "";
    public string SectionName { get; set; } = "";
    public List<MarksGridEntry> Entries { get; set; } = new();
}
public class MarksGridEntry
{
    public long StudentId { get; set; }
    public string Subject { get; set; } = "";
    /// <summary>Null clears the mark — the student is left unmarked for that subject.</summary>
    public decimal? Marks { get; set; }
}

/* -------- timetable -------- */
public record TimetableSlotDto(int DayOfWeek, int PeriodNo, string? Time, string? Label, string? Room);

/// <summary>A period column of the timetable grid, shared by the admin and portal views.</summary>
public record TimetablePeriodDto(int PeriodNo, string Name, string TimeLabel, bool IsBreak);

/// <summary>
/// A teacher's week: the school's period columns plus only the slots they teach. The columns
/// have to travel with the slots — period numbers include breaks, so a client that assumes
/// 1..6 mislabels every period after the break and drops the last one entirely.
/// </summary>
public record TeacherTimetableDto(
    IReadOnlyList<TimetablePeriodDto> Periods,
    IReadOnlyList<TimetableSlotDto> Slots);

/* -------- fees -------- */
public record FeeInvoiceDto(long Id, string? InvoiceNo, string? StudentName, string? ClassLabel, string? Month, decimal Amount, decimal Paid, decimal Balance, DateTime? DueDate, string Status);
public record FeeSummaryDto(decimal TotalBilled, decimal Collected, decimal Outstanding, int Unpaid, int Overdue);
public class RecordFeePaymentDto { public decimal Amount { get; set; } public string Method { get; set; } = "cash"; public string? Ref { get; set; } public DateTime PaymentDate { get; set; } = DateTime.UtcNow; }
public class GenerateInvoicesDto
{
    public string Month { get; set; } = "";
    public DateTime DueDate { get; set; }
    public string ClassName { get; set; } = "All";
    /// <summary>Adds the yearly and one-time heads on top of the monthly ones.</summary>
    public bool IncludeOneOff { get; set; }
}
/// <summary>One head's share of an invoice total.</summary>
public record FeeInvoiceLineDto(string Description, decimal Amount);
/// <summary>
/// Outcome of an invoice run. <paramref name="UnpricedClasses"/> names classes skipped for having
/// no amounts in the fee structure — the admin needs to be told, not left with a silent zero.
/// </summary>
public record GenerateInvoicesResultDto(int Created, int AlreadyBilled, IReadOnlyList<string> UnpricedClasses);
