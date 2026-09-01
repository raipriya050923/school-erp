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
    /// <summary>Sections and subjects this teacher may enter marks for, from their assignments.</summary>
    Task<IReadOnlyList<TeachingSectionDto>> GetTeachingSectionsAsync(CancellationToken ct = default);
    /// <summary>Every subject against every student, for entering a whole exam in one pass.</summary>
    Task<MarksGridDto> GetMarksGridAsync(long examId, string className, string sectionName, CancellationToken ct = default);
    /// <summary>Saves the grid. Returns the number of marks written.</summary>
    Task<int> SaveMarksGridAsync(SaveMarksGridDto dto, CancellationToken ct = default);
    /// <summary>The exam's papers for one section, with marks-entered counts.</summary>
    Task<IReadOnlyList<MarksProgressDto>> GetMarksProgressAsync(long examId, string className, string sectionName, CancellationToken ct = default);
    /// <summary>Sections this teacher is class teacher of — what they may review results for.</summary>
    Task<IReadOnlyList<MyClassSectionDto>> GetMyClassSectionsAsync(CancellationToken ct = default);
    /// <summary>
    /// The whole section's marks for one exam, read-only. Restricted to the section's class
    /// teacher: reviewing every subject is their job, entering them is the subject teacher's.
    /// </summary>
    Task<ClassResultDto> GetClassResultAsync(long examId, string className, string sectionName, CancellationToken ct = default);
    /// <summary>
    /// The class teacher signs their section's sheet off, or withdraws it. Only once approved may
    /// an admin publish the exam.
    /// </summary>
    Task ApproveResultAsync(ApproveResultDto dto, CancellationToken ct = default);
    Task<TeacherTimetableDto> GetTimetableAsync(CancellationToken ct = default);
}
