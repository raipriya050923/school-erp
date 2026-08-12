namespace SchoolErp.Application.DTOs.Admin;

public record AdminDashboardDto(
    int TotalStudents,
    int TotalTeachers,
    int TeachersOnLeave,
    int TotalClasses,
    decimal FeesDue,
    IReadOnlyList<RecentAdmissionDto> RecentAdmissions,
    IReadOnlyList<NoticeDto> LatestNotices);

public record RecentAdmissionDto(string Name, string? ClassName, string? SectionName, DateTime? AdmissionDate);
