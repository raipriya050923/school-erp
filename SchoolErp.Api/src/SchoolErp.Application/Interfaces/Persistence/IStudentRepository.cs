using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IStudentRepository
{
    /// <summary>One page of the roster plus the total number of rows the filter matches.</summary>
    Task<(IReadOnlyList<Student> Rows, int Total)> GetPageAsync(
        long schoolId, string? search, string? className, DateTime? admittedFrom, DateTime? admittedTo,
        int offset, int limit, CancellationToken ct = default);
    Task<Student?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<long> CreateAsync(Student s, CancellationToken ct = default);
    Task UpdateAsync(Student s, CancellationToken ct = default);
    Task SetStatusAsync(long schoolId, long id, string status, CancellationToken ct = default);
    Task<int> CountAsync(long schoolId, CancellationToken ct = default);
    Task<decimal> TotalFeesDueAsync(long schoolId, CancellationToken ct = default);
    Task<IReadOnlyList<Student>> RecentAsync(long schoolId, int take, CancellationToken ct = default);
    Task<string> NextAdmissionNoAsync(long schoolId, CancellationToken ct = default);
    Task<string> NextRollNoAsync(long schoolId, string? className, string? sectionName, CancellationToken ct = default);
    /// <summary>
    /// Whether an active student of that name already sits in the section. Used by the bulk
    /// importer: re-uploading the same sheet would otherwise admit everyone twice, each with a
    /// fresh admission number, and nothing in the schema forbids it.
    /// </summary>
    Task<bool> ExistsInSectionAsync(long schoolId, string firstName, string lastName, string? className, string? sectionName, CancellationToken ct = default);
    /// <summary>Links the student row to its login account; the student portal resolves student_id from this.</summary>
    Task SetUserIdAsync(long schoolId, long id, long userId, CancellationToken ct = default);
}
