namespace SchoolErp.Application.DTOs.Student;

public record StudentProfileDto(long Id, string AdmissionNo, string Name, string? ClassName, string? SectionName, string? RollNo);

public record StudentDashboardDto(
    string Name, string? ClassName, string? SectionName, string? RollNo,
    int AttendancePercent, int PresentDays, int TotalDays,
    int PendingHomework, string? NextExamName, DateTime? NextExamDate, decimal FeeDue,
    IReadOnlyList<StudentHomeworkDto> UpcomingHomework);

public record AttendanceMonthDto(string Month, int Present, int Absent, int Late, int Percent);
public record AttendanceRecentDto(string Date, string Day, string Status);
public record StudentAttendanceDto(
    int OverallPercent, int PresentDays, int TotalDays,
    IReadOnlyList<AttendanceMonthDto> Months, IReadOnlyList<AttendanceRecentDto> Recent);

public record StudentTimetableSlotDto(int DayOfWeek, int PeriodNo, string? Time, string? Subject, string? Room);

/// <summary>
/// A class timetable with the columns and rows it should be drawn on. Periods and working days
/// come from the school, not from a fixed grid: period numbers count breaks, so a hardcoded
/// 1..6 mislabels everything after the break and drops the last period of the day entirely.
/// </summary>
public record StudentTimetableDto(
    /// <summary>Whose timetable this is — an empty grid means nothing without it.</summary>
    string? ClassName, string? SectionName,
    IReadOnlyList<StudentTimetablePeriodDto> Periods,
    IReadOnlyList<int> WorkingDays,
    IReadOnlyList<StudentTimetableSlotDto> Slots);

public record StudentTimetablePeriodDto(int PeriodNo, string Name, string TimeLabel, bool IsBreak);

public record StudentHomeworkDto(string Title, string? Subject, DateTime? DueDate, string Status);

public record StudentResultDto(string Subject, decimal FullMarks, decimal? Marks, string Grade);
public record UpcomingPaperDto(DateTime? Date, string Subject, string? Time, string? Room);
public record StudentExamsDto(
    string? ExamName, decimal Total, decimal FullTotal, int Percent, string Grade,
    IReadOnlyList<StudentResultDto> Results, IReadOnlyList<UpcomingPaperDto> Upcoming);

/// <summary>
/// One invoice as the student sees it. <paramref name="Id"/> is what a payment is submitted
/// against, and <paramref name="HasPendingSubmission"/> is why the Pay button turns into
/// "awaiting confirmation" rather than letting the same transfer be declared twice.
/// </summary>
public record StudentFeeDto(long Id, string? InvoiceNo, string? Month, decimal Amount, decimal Paid,
    decimal Balance, DateTime? DueDate, string Status, bool HasPendingSubmission);

/// <summary>
/// A payment the student says they have made. The school has to confirm it against its own
/// statement, so nothing here changes what is owed until it is verified.
/// </summary>
public class SubmitFeePaymentDto
{
    public decimal Amount { get; set; }
    /// <summary>How it was paid — upi, bank_transfer, cash, cheque, esewa, khalti…</summary>
    public string Method { get; set; } = string.Empty;
    /// <summary>The UPI/UTR/cheque number the office will match against the bank statement.</summary>
    public string? Reference { get; set; }
    public DateTime? PaidDate { get; set; }
    public string? Note { get; set; }
}

/// <summary>A submitted payment and where it has got to, for the student's own history.</summary>
public record StudentFeeSubmissionDto(
    long Id, long InvoiceId, string? InvoiceNo, string? Month, decimal Amount, string Method,
    string? Reference, DateTime PaidDate, string Status, DateTime SubmittedAt,
    DateTime? ReviewedAt,
    /// <summary>Why it was turned down. The whole point of showing a rejection.</summary>
    string? ReviewNote);

public record StudentNoticeDto(long Id, string Title, string Body, string Audience, DateTime PublishDate);
