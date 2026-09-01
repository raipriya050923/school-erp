using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.DTOs.Schools;

namespace SchoolErp.Application.Interfaces.Services;

public interface ISchoolService
{
    Task<IReadOnlyList<SchoolListItemDto>> ListAsync(string? search, string? status, CancellationToken ct = default);
    Task<SchoolDetailDto?> GetAsync(long id, CancellationToken ct = default);
    /// <summary>Creates the tenant plus its first school_admin login, returning the generated credentials.</summary>
    Task<CreateSchoolResultDto> CreateAsync(CreateSchoolDto dto, CancellationToken ct = default);
    Task UpdateAsync(long id, UpdateSchoolDto dto, CancellationToken ct = default);
    Task ChangeStatusAsync(long id, string status, CancellationToken ct = default);

    /// <summary>
    /// Issues a fresh password for the school's admin login and returns it. This is the only way
    /// to learn an existing account's password — the stored value is a one-way bcrypt hash.
    /// </summary>
    Task<GeneratedCredentialsDto> ResetAdminPasswordAsync(long id, CancellationToken ct = default);
}
