using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ISchoolRepository
{
    Task<IReadOnlyList<School>> GetAllAsync(string? search, string? status, CancellationToken ct = default);
    Task<School?> GetByIdAsync(long id, CancellationToken ct = default);
    Task<long> CreateAsync(School school, CancellationToken ct = default);
    Task UpdateAsync(School school, CancellationToken ct = default);
    Task UpdateStatusAsync(long id, string status, CancellationToken ct = default);
    Task<bool> ExistsByNameAsync(string name, long? excludeId, CancellationToken ct = default);
    Task<int> CountAsync(CancellationToken ct = default);
    Task<int> GetStudentCountAsync(long schoolId, CancellationToken ct = default);
}
