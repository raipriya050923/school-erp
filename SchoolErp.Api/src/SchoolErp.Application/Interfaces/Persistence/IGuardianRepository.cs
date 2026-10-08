using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IGuardianRepository
{
    /// <summary>The guardian linked to a student, if one has been recorded.</summary>
    Task<Guardian?> GetForStudentAsync(long schoolId, long studentId, CancellationToken ct = default);

    Task<long> CreateAsync(Guardian guardian, CancellationToken ct = default);

    /// <summary>Links a guardian to a student. Idempotent — the pair is the primary key.</summary>
    Task LinkAsync(long studentId, long guardianId, bool isPrimary, CancellationToken ct = default);

    /// <summary>Attaches a freshly provisioned login to an existing guardian row.</summary>
    Task SetUserIdAsync(long schoolId, long guardianId, long userId, CancellationToken ct = default);

    /// <summary>
    /// Student ids in the school that already have a parent login, so the list can
    /// show which rows still need one without a query per row.
    /// </summary>
    Task<IReadOnlyList<long>> GetStudentIdsWithParentLoginAsync(long schoolId, CancellationToken ct = default);
}
