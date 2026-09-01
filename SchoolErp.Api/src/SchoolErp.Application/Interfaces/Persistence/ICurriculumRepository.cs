using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

/// <summary>Which subjects a class studies, and who teaches each one to each section.</summary>
public interface ICurriculumRepository
{
    Task<IReadOnlyList<ClassSubject>> GetClassSubjectsAsync(long schoolId, long academicYearId, long classId, CancellationToken ct = default);
    /// <summary>Replaces the class's subject set; rows dropped from the set are deleted.</summary>
    Task SetClassSubjectsAsync(long schoolId, long academicYearId, long classId, IEnumerable<long> subjectIds, CancellationToken ct = default);
    /// <summary>Subject ids still referenced by an assignment — deleting these would orphan a teacher.</summary>
    Task<IReadOnlyList<long>> GetAssignedSubjectIdsAsync(long academicYearId, long classId, CancellationToken ct = default);

    Task<IReadOnlyList<TeacherAssignment>> GetAssignmentsForClassAsync(long schoolId, long academicYearId, long classId, CancellationToken ct = default);
    Task<IReadOnlyList<TeacherAssignment>> GetAssignmentsForTeacherAsync(long schoolId, long academicYearId, long staffId, CancellationToken ct = default);
    /// <summary>Removes every teacher assignment for a class in one statement. Returns how many went.</summary>
    Task<int> ClearAssignmentsForClassAsync(long schoolId, long academicYearId, long classId, CancellationToken ct = default);
    /// <summary>Sets the single teacher for (section, subject); a null staffId clears it.</summary>
    Task AssignAsync(long schoolId, long academicYearId, long classId, long sectionId, long subjectId, long? staffId, CancellationToken ct = default);
}
