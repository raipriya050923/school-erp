using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface INoticeRepository
{
    Task<IReadOnlyList<Notice>> GetAllAsync(long schoolId, int? take, CancellationToken ct = default);
    Task<Notice?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<long> CreateAsync(Notice n, CancellationToken ct = default);
    Task UpdateAsync(Notice n, CancellationToken ct = default);
    Task DeleteAsync(long schoolId, long id, CancellationToken ct = default);
}
