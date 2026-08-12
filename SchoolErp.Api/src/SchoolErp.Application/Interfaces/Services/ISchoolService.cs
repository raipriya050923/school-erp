using SchoolErp.Application.DTOs.Schools;

namespace SchoolErp.Application.Interfaces.Services;

public interface ISchoolService
{
    Task<IReadOnlyList<SchoolListItemDto>> ListAsync(string? search, string? status, CancellationToken ct = default);
    Task<SchoolDetailDto?> GetAsync(long id, CancellationToken ct = default);
    Task<long> CreateAsync(CreateSchoolDto dto, CancellationToken ct = default);
    Task UpdateAsync(long id, UpdateSchoolDto dto, CancellationToken ct = default);
    Task ChangeStatusAsync(long id, string status, CancellationToken ct = default);
}
