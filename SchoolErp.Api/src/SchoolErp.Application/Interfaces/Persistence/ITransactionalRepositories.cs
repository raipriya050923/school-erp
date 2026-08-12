using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IAttendanceRepository
{
    Task<IReadOnlyList<DailyAttendance>> GetSectionAsync(long schoolId, string className, string sectionName, DateTime date, CancellationToken ct = default);
    Task UpsertAsync(long schoolId, string className, string sectionName, DateTime date, IEnumerable<(long studentId, string status)> entries, CancellationToken ct = default);
    Task<IReadOnlyList<DailyAttendance>> GetStudentRangeAsync(long schoolId, long studentId, DateTime from, DateTime to, CancellationToken ct = default);
}

public interface IExamRepository
{
    Task<IReadOnlyList<Exam>> GetAllWithPapersAsync(long schoolId, CancellationToken ct = default);
    Task<long> CreateExamAsync(Exam e, CancellationToken ct = default);
    Task<long> AddPaperAsync(ExamPaper p, CancellationToken ct = default);
    Task DeletePaperAsync(long schoolId, long paperId, CancellationToken ct = default);
    Task<bool> PaperSubjectExistsAsync(long examId, string subject, CancellationToken ct = default);
    Task<IReadOnlyList<StudentMark>> GetMarksAsync(long schoolId, long examId, string className, string sectionName, string subject, CancellationToken ct = default);
    Task UpsertMarksAsync(long schoolId, long examId, string subject, int fullMarks, IEnumerable<(long studentId, decimal? marks)> entries, CancellationToken ct = default);
}

public interface ITimetableRepository
{
    Task<IReadOnlyList<TimetableSlot>> GetByTeacherAsync(long schoolId, long staffId, CancellationToken ct = default);
}

public interface IFeeRepository
{
    Task<IReadOnlyList<FeeInvoiceRow>> GetInvoicesAsync(long schoolId, string? status, CancellationToken ct = default);
    Task<FeeInvoiceRow?> GetInvoiceAsync(long schoolId, long id, CancellationToken ct = default);
    Task RecordPaymentAsync(long schoolId, long invoiceId, decimal amount, string method, string? reference, DateTime date, CancellationToken ct = default);
    Task<int> GenerateAsync(long schoolId, string month, DateTime due, string className, CancellationToken ct = default);
}
