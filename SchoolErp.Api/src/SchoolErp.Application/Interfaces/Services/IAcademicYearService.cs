using SchoolErp.Application.DTOs.Admin;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>School sessions: the year everything year-scoped is filed under.</summary>
public interface IAcademicYearService
{
    Task<IReadOnlyList<AcademicYearDto>> ListAsync(CancellationToken ct = default);
    Task<long> CreateAsync(SaveAcademicYearDto dto, CancellationToken ct = default);
    Task UpdateAsync(long id, SaveAcademicYearDto dto, CancellationToken ct = default);
    Task SetCurrentAsync(long id, CancellationToken ct = default);
    Task DeleteAsync(long id, CancellationToken ct = default);
}
