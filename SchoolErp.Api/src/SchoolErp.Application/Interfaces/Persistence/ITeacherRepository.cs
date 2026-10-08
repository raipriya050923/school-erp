using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ITeacherRepository
{
    Task<IReadOnlyList<StaffMember>> GetAllAsync(long schoolId, string? search, CancellationToken ct = default);
    Task<StaffMember?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<long> CreateAsync(StaffMember s, CancellationToken ct = default);
    Task UpdateAsync(StaffMember s, CancellationToken ct = default);
    Task SetStatusAsync(long schoolId, long id, string status, CancellationToken ct = default);
    Task<int> CountAsync(long schoolId, string? status, CancellationToken ct = default);
    Task<string> NextEmployeeCodeAsync(long schoolId, CancellationToken ct = default);
    /// <summary>Links the staff row to its login account; the teacher portal resolves staff_id from this.</summary>
    Task SetUserIdAsync(long schoolId, long id, long userId, CancellationToken ct = default);

    /// <summary>
    /// Staff id → the section they are class teacher of ("Grade 6 — A"). One lookup for the whole
    /// list rather than a query per teacher.
    /// </summary>
    Task<IReadOnlyDictionary<long, string>> GetClassTeacherSectionsAsync(long schoolId, CancellationToken ct = default);

    /// <summary>
    /// The subjects this teacher is able to take. A teacher commonly teaches more than one, and
    /// the Subjects &amp; Teachers grid offers them for every subject on this list.
    /// </summary>
    Task<IReadOnlyList<string>> GetSubjectsAsync(long schoolId, long staffId, CancellationToken ct = default);
    /// <summary>Replaces the whole set. Names are resolved against the school's own subjects.</summary>
    Task ReplaceSubjectsAsync(long schoolId, long staffId, IEnumerable<string> subjectNames, CancellationToken ct = default);
    /// <summary>Every teacher's subject list at once, keyed by staff id — one query for the list screen.</summary>
    Task<IReadOnlyDictionary<long, IReadOnlyList<string>>> GetSubjectsForAllAsync(long schoolId, CancellationToken ct = default);

    /// <summary>A staff member's qualifications, in the order the admin entered them.</summary>
    Task<IReadOnlyList<StaffQualification>> GetQualificationsAsync(long schoolId, long staffId, CancellationToken ct = default);
    /// <summary>Replaces the whole set — the form always posts the complete list.</summary>
    Task ReplaceQualificationsAsync(long schoolId, long staffId, IEnumerable<StaffQualification> qualifications, CancellationToken ct = default);
}
