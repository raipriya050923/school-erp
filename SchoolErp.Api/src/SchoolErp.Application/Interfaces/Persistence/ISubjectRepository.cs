using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ISubjectRepository
{
    Task<IReadOnlyList<Subject>> GetAllAsync(long schoolId, CancellationToken ct = default);
    /// <summary>Active subject names only — what the exam Add Subject dropdown offers.</summary>
    Task<IReadOnlyList<string>> GetNamesAsync(long schoolId, CancellationToken ct = default);
    Task<Subject?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<bool> ExistsByNameAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default);
    Task<long> CreateAsync(Subject subject, CancellationToken ct = default);
    Task UpdateAsync(Subject subject, CancellationToken ct = default);
    Task SetActiveAsync(long schoolId, long id, bool isActive, CancellationToken ct = default);

    /// <summary>
    /// Gives a school the default subject set. Existing names are left alone, so this is safe to
    /// call on a school that already has subjects.
    /// </summary>
    Task SeedDefaultsAsync(long schoolId, CancellationToken ct = default);
}
