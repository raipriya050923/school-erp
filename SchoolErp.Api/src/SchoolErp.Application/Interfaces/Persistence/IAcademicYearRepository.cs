using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IAcademicYearRepository
{
    Task<IReadOnlyList<AcademicYear>> GetAllAsync(long schoolId, CancellationToken ct = default);
    Task<AcademicYear?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<bool> NameExistsAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default);
    /// <summary>Another year whose date range overlaps the one given, if any.</summary>
    Task<AcademicYear?> FindOverlapAsync(long schoolId, DateTime start, DateTime end, long? excludeId, CancellationToken ct = default);
    Task<long> CreateAsync(AcademicYear year, CancellationToken ct = default);
    Task UpdateAsync(AcademicYear year, CancellationToken ct = default);
    /// <summary>Flags one year current and clears the rest — exactly one is current at a time.</summary>
    Task SetCurrentAsync(long schoolId, long id, CancellationToken ct = default);
    Task DeleteAsync(long schoolId, long id, CancellationToken ct = default);
    /// <summary>Rows in other tables keyed to this year, which a delete would orphan.</summary>
    Task<int> UsageCountAsync(long id, CancellationToken ct = default);
}
