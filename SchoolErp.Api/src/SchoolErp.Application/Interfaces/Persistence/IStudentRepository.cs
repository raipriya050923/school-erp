using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IStudentRepository
{
    Task<IReadOnlyList<Student>> GetAllAsync(long schoolId, string? search, string? className, CancellationToken ct = default);
    Task<Student?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<long> CreateAsync(Student s, CancellationToken ct = default);
    Task UpdateAsync(Student s, CancellationToken ct = default);
    Task SetStatusAsync(long schoolId, long id, string status, CancellationToken ct = default);
    Task<int> CountAsync(long schoolId, CancellationToken ct = default);
    Task<decimal> TotalFeesDueAsync(long schoolId, CancellationToken ct = default);
    Task<IReadOnlyList<Student>> RecentAsync(long schoolId, int take, CancellationToken ct = default);
    Task<string> NextAdmissionNoAsync(long schoolId, CancellationToken ct = default);
}
