using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IClassRepository
{
    Task<IReadOnlyList<SchoolClass>> GetAllWithSectionsAsync(long schoolId, CancellationToken ct = default);
    Task<SchoolClass?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<bool> ExistsByNameAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default);
    Task<long> CreateClassAsync(long schoolId, string name, CancellationToken ct = default);
    Task RenameClassAsync(long schoolId, long id, string name, CancellationToken ct = default);
    Task DeleteClassAsync(long schoolId, long id, CancellationToken ct = default);
    Task<int> CountAsync(long schoolId, CancellationToken ct = default);

    Task<bool> SectionExistsAsync(long classId, string name, long? excludeId, CancellationToken ct = default);
    Task<long> AddSectionAsync(long schoolId, long classId, string name, string? teacher, CancellationToken ct = default);
    Task UpdateSectionAsync(long schoolId, long id, string name, string? teacher, CancellationToken ct = default);
    Task DeleteSectionAsync(long schoolId, long id, CancellationToken ct = default);
}
