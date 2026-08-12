using SchoolErp.Application.DTOs.Teacher;
using SchoolErp.Application.DTOs.Transactional;

namespace SchoolErp.Application.Interfaces.Services;

public interface ITeacherPortalService
{
    Task<TeacherDashboardDto> GetDashboardAsync(CancellationToken ct = default);
    Task<TeacherProfileDto?> GetProfileAsync(CancellationToken ct = default);
    Task<IReadOnlyList<MyClassDto>> GetMyClassesAsync(CancellationToken ct = default);
    Task<IReadOnlyList<RosterStudentDto>> GetRosterAsync(string className, string sectionName, CancellationToken ct = default);
    Task<IReadOnlyList<HomeworkDto>> GetHomeworkAsync(CancellationToken ct = default);
    Task<long> CreateHomeworkAsync(CreateHomeworkDto dto, CancellationToken ct = default);

    // Attendance / Marks / Timetable
    Task<IReadOnlyList<AttendanceRowDto>> GetAttendanceAsync(string className, string sectionName, DateTime date, CancellationToken ct = default);
    Task SaveAttendanceAsync(SaveAttendanceDto dto, CancellationToken ct = default);
    Task<IReadOnlyList<ExamDto>> GetExamsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<MarkRowDto>> GetMarksAsync(long examId, string className, string sectionName, string subject, CancellationToken ct = default);
    Task SaveMarksAsync(SaveMarksDto dto, CancellationToken ct = default);
    Task<IReadOnlyList<TimetableSlotDto>> GetTimetableAsync(CancellationToken ct = default);
}
