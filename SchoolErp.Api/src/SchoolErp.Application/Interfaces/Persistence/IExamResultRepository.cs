using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

/// <summary>
/// Stored exam results and the class-teacher approval that gates publishing them.
/// </summary>
public interface IExamResultRepository
{
    /// <summary>The school's grade bands, highest first. Empty when none are configured.</summary>
    Task<IReadOnlyList<GradeBand>> GetGradeScaleAsync(long schoolId, CancellationToken ct = default);

    /// <summary>
    /// Recomputes and stores the result row for every student of one section, from the marks
    /// currently recorded. Called after any save of marks, so the stored figures never lag the
    /// marks they come from. Returns the number of rows written.
    /// </summary>
    Task<int> RecomputeSectionAsync(long schoolId, long examId, string className, string sectionName,
        IReadOnlyList<GradeBand> scale, CancellationToken ct = default);

    Task<IReadOnlyList<ExamResultRow>> GetSectionResultsAsync(long schoolId, long examId, string className, string sectionName, CancellationToken ct = default);

    /// <summary>The approval row for one section, creating a pending one if it does not exist yet.</summary>
    Task<ExamSectionApproval> GetApprovalAsync(long schoolId, long examId, string className, string sectionName, CancellationToken ct = default);
    /// <summary>Every section of an exam that has papers, with its approval state — the admin's publish checklist.</summary>
    Task<IReadOnlyList<ExamSectionApproval>> GetExamApprovalsAsync(long schoolId, long examId, CancellationToken ct = default);
    Task SetApprovalAsync(long schoolId, long examId, string className, string sectionName,
        string status, long? approvedBy, string? remarks, CancellationToken ct = default);
    /// <summary>
    /// Drops a section back to pending. Marks changing after sign-off invalidate it — the sheet
    /// that was approved is no longer the sheet on file.
    /// </summary>
    Task ResetApprovalAsync(long schoolId, long examId, string className, string sectionName, CancellationToken ct = default);
}
