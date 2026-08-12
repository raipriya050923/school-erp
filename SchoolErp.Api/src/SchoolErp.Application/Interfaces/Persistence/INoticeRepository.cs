using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface INoticeRepository
{
    Task<IReadOnlyList<Notice>> GetAllAsync(long schoolId, int? take, CancellationToken ct = default);
    Task<long> CreateAsync(Notice n, CancellationToken ct = default);
}
