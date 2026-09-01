using SchoolErp.Application.DTOs.Student;

namespace SchoolErp.Application.Interfaces.Services;

public interface IStudentPortalService
{
    Task<StudentDashboardDto> GetDashboardAsync(CancellationToken ct = default);
    Task<StudentProfileDto?> GetProfileAsync(CancellationToken ct = default);
    Task<StudentAttendanceDto> GetAttendanceAsync(CancellationToken ct = default);
    Task<StudentTimetableDto> GetTimetableAsync(CancellationToken ct = default);
    Task<IReadOnlyList<StudentHomeworkDto>> GetHomeworkAsync(CancellationToken ct = default);
    Task<StudentExamsDto> GetExamsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<StudentFeeDto>> GetFeesAsync(CancellationToken ct = default);
    Task<IReadOnlyList<StudentNoticeDto>> GetNoticesAsync(CancellationToken ct = default);
}
