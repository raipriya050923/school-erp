using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IFeeStructureRepository
{
    /* ---- heads ---- */
    Task<IReadOnlyList<FeeHead>> GetHeadsAsync(long schoolId, CancellationToken ct = default);
    Task<FeeHead?> GetHeadAsync(long schoolId, long id, CancellationToken ct = default);
    Task<bool> HeadNameExistsAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default);
    Task<long> CreateHeadAsync(FeeHead head, CancellationToken ct = default);
    Task UpdateHeadAsync(FeeHead head, CancellationToken ct = default);
    Task SetHeadActiveAsync(long schoolId, long id, bool isActive, CancellationToken ct = default);
    /// <summary>Gives a school the default head set. Existing names are left alone.</summary>
    Task SeedDefaultHeadsAsync(long schoolId, CancellationToken ct = default);

    /* ---- priced cells ---- */
    /// <summary>Every priced (class, head) pair for one academic year. Unpriced pairs are absent.</summary>
    Task<IReadOnlyList<FeeStructureCell>> GetCellsAsync(long schoolId, long academicYearId, CancellationToken ct = default);
    /// <summary>
    /// Writes one cell. An amount of zero removes the row instead of storing a zero charge, so
    /// "not billed" and "billed nothing" stay the same thing and the invoice run stays simple.
    /// </summary>
    Task SaveCellAsync(long schoolId, long academicYearId, long classId, long feeTypeId, decimal amount, CancellationToken ct = default);
    /// <summary>Copies every priced cell from one academic year to another, skipping pairs the target already prices.</summary>
    Task<int> CopyYearAsync(long schoolId, long fromAcademicYearId, long toAcademicYearId, CancellationToken ct = default);
}
