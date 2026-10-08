using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ITransportRepository
{
    /* ---- distance bands ---- */
    Task<IReadOnlyList<TransportSlab>> GetSlabsAsync(long schoolId, long academicYearId, long feeTypeId, CancellationToken ct = default);
    /// <summary>
    /// Replaces the whole band set for one (year, head) in a single transaction. A band set is
    /// only meaningful as a set: saving row by row would leave a half-applied scale live, and an
    /// invoice run in that moment would bill from it.
    /// </summary>
    Task ReplaceSlabsAsync(long schoolId, long academicYearId, long feeTypeId, IReadOnlyList<TransportSlab> slabs, CancellationToken ct = default);
    /// <summary>Copies a band set into another year, leaving a year that already has bands alone.</summary>
    Task<int> CopySlabsAsync(long schoolId, long fromAcademicYearId, long toAcademicYearId, long feeTypeId, CancellationToken ct = default);

    /* ---- who rides ---- */
    Task<IReadOnlyList<StudentTransport>> GetAssignmentsAsync(long schoolId, CancellationToken ct = default);
    Task<StudentTransport?> GetAssignmentAsync(long schoolId, long studentId, CancellationToken ct = default);
    /// <summary>
    /// Writes one student's transport details, creating the row the first time. Returns false if
    /// the student does not belong to this school, in which case nothing was written.
    /// </summary>
    Task<bool> SaveAssignmentAsync(StudentTransport assignment, CancellationToken ct = default);
}
