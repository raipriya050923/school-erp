using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IStudentPortalRepository
{
    Task<Student?> GetProfileAsync(long schoolId, long studentId, CancellationToken ct = default);
    Task<IReadOnlyList<DailyAttendance>> GetAttendanceAsync(long schoolId, long studentId, CancellationToken ct = default);
    Task<IReadOnlyList<TeacherHomework>> GetHomeworkAsync(long schoolId, string className, string? classSection, CancellationToken ct = default);
    Task<IReadOnlyList<TimetableSlot>> GetTimetableAsync(long schoolId, string className, string sectionName, CancellationToken ct = default);
    Task<Exam?> GetPublishedExamAsync(long schoolId, CancellationToken ct = default);
    Task<IReadOnlyList<StudentMark>> GetMarksAsync(long schoolId, long studentId, long examId, CancellationToken ct = default);
    Task<IReadOnlyList<ExamPaper>> GetUpcomingPapersAsync(long schoolId, string className, CancellationToken ct = default);
    Task<IReadOnlyList<FeeInvoiceRow>> GetFeesAsync(long schoolId, long studentId, CancellationToken ct = default);
    Task<IReadOnlyList<Notice>> GetNoticesAsync(long schoolId, CancellationToken ct = default);
}
