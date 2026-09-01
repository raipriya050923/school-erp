using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ITeacherPortalRepository
{
    Task<StaffMember?> GetProfileAsync(long schoolId, long staffId, CancellationToken ct = default);
    /// <summary>Sections this teacher is class teacher of — their attendance responsibility.</summary>
    Task<IReadOnlyList<TeacherClassRow>> GetMyClassesAsync(long schoolId, long staffId, CancellationToken ct = default);
    /// <summary>
    /// Subject-and-section pairs this teacher is assigned, in the current academic year. Marks
    /// entry is scoped to these: being class teacher of a section does not confer the right to
    /// mark another teacher's subject in it.
    /// </summary>
    Task<IReadOnlyList<TeacherAssignmentRow>> GetMyAssignmentsAsync(long schoolId, long staffId, CancellationToken ct = default);
    /// <summary>True when this teacher is the class teacher of the named section.</summary>
    Task<bool> IsClassTeacherOfAsync(long schoolId, long staffId, string className, string sectionName, CancellationToken ct = default);
    /// <summary>
    /// Subject-to-teacher for one section in the current year, whoever the caller is. Lets a
    /// class teacher's review name the colleague whose marks are still outstanding.
    /// </summary>
    Task<IReadOnlyList<SubjectTeacherRow>> GetSectionSubjectTeachersAsync(long schoolId, string className, string sectionName, CancellationToken ct = default);
    Task<IReadOnlyList<Student>> GetRosterAsync(long schoolId, string className, string sectionName, CancellationToken ct = default);
    Task<IReadOnlyList<TeacherHomework>> GetHomeworkAsync(long schoolId, long staffId, CancellationToken ct = default);
    Task<long> CreateHomeworkAsync(TeacherHomework h, CancellationToken ct = default);
}
