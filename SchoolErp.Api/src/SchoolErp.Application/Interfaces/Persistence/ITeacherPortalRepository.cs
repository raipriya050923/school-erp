using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ITeacherPortalRepository
{
    Task<StaffMember?> GetProfileAsync(long schoolId, long staffId, CancellationToken ct = default);
    Task<IReadOnlyList<TeacherClassRow>> GetMyClassesAsync(long schoolId, long staffId, CancellationToken ct = default);
    Task<IReadOnlyList<Student>> GetRosterAsync(long schoolId, string className, string sectionName, CancellationToken ct = default);
    Task<IReadOnlyList<TeacherHomework>> GetHomeworkAsync(long schoolId, long staffId, CancellationToken ct = default);
    Task<long> CreateHomeworkAsync(TeacherHomework h, CancellationToken ct = default);
}
