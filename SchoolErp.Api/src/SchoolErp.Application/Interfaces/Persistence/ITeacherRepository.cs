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
}
