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

public record StudentHomeworkDto(string Title, string? Subject, DateTime? DueDate, string Status);

public record StudentResultDto(string Subject, decimal FullMarks, decimal? Marks, string Grade);
public record UpcomingPaperDto(DateTime? Date, string Subject, string? Time, string? Room);
public record StudentExamsDto(
    string? ExamName, decimal Total, decimal FullTotal, int Percent, string Grade,
    IReadOnlyList<StudentResultDto> Results, IReadOnlyList<UpcomingPaperDto> Upcoming);

public record StudentFeeDto(string? InvoiceNo, string? Month, decimal Amount, decimal Paid, decimal Balance, DateTime? DueDate, string Status);

public record StudentNoticeDto(long Id, string Title, string Body, string Audience, DateTime PublishDate);
