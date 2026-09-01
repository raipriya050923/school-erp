using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

/// <summary>
/// Records that would be orphaned by deleting a class or section. Configuration the school can
/// simply re-enter (subjects, teacher assignments, timetable slots) is not counted here — that
/// is removed with the class. These are the things that represent history.
/// </summary>
public record ClassUsage(int Students, int Enrollments, int FeeStructures, int ExamSchedules)
{
    public bool Any => Students > 0 || Enrollments > 0 || FeeStructures > 0 || ExamSchedules > 0;
}

public interface IClassRepository
{
    Task<IReadOnlyList<SchoolClass>> GetAllWithSectionsAsync(long schoolId, CancellationToken ct = default);
    Task<SchoolClass?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<bool> ExistsByNameAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default);
    Task<long> CreateClassAsync(long schoolId, string name, CancellationToken ct = default);
    Task RenameClassAsync(long schoolId, long id, string name, CancellationToken ct = default);
    /// <summary>What a delete would orphan; check before calling <see cref="DeleteClassAsync"/>.</summary>
    Task<ClassUsage> GetClassUsageAsync(long schoolId, long classId, CancellationToken ct = default);
    Task DeleteClassAsync(long schoolId, long id, CancellationToken ct = default);
    Task<int> CountAsync(long schoolId, CancellationToken ct = default);

    Task<bool> SectionExistsAsync(long classId, string name, long? excludeId, CancellationToken ct = default);
    Task<long> AddSectionAsync(long schoolId, long classId, string name, string? teacher, CancellationToken ct = default);
    Task UpdateSectionAsync(long schoolId, long id, string name, string? teacher, CancellationToken ct = default);
    Task<ClassUsage> GetSectionUsageAsync(long schoolId, long sectionId, CancellationToken ct = default);
    Task DeleteSectionAsync(long schoolId, long id, CancellationToken ct = default);
}
