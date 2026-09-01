namespace SchoolErp.Application.DTOs.Admin;

public record AdminDashboardDto(
    string SchoolName,
    string? AcademicYear,
    int TotalStudents,
    int TotalTeachers,
    int TeachersOnLeave,
    int TotalClasses,
    int TotalSections,
    decimal FeesDue,
    decimal FeesBilled,
    decimal FeesCollected,
    decimal FeesOverdue,
    int UnpaidInvoices,
    /// <summary>Percent present today, or null when nobody has marked attendance yet.</summary>
    double? AttendanceToday,
    IReadOnlyList<AttendancePointDto> AttendanceTrend,
    IReadOnlyList<RecentAdmissionDto> RecentAdmissions,
    IReadOnlyList<NoticeDto> LatestNotices);

/// <summary>One day of school-wide attendance for the dashboard trend line.</summary>
public record AttendancePointDto(DateTime Date, double Percent, int Present, int Total);

public record RecentAdmissionDto(string Name, string? ClassName, string? SectionName, DateTime? AdmissionDate);
