namespace SchoolErp.Application.DTOs.Admin;

/// <summary>One subject offered by the school, flagged with whether this class studies it.</summary>
public record ClassSubjectOptionDto(long SubjectId, string Name, bool Selected, bool HasTeacher);

/// <summary>The teacher teaching one subject to one section — a cell of the assignment grid.</summary>
public record AssignmentCellDto(long SectionId, string SectionName, long? StaffId, string? TeacherName);

/// <summary>One row of the grid: a subject, with a cell per section of the class.</summary>
public record AssignmentRowDto(long SubjectId, string SubjectName, IReadOnlyList<AssignmentCellDto> Sections);

/// <summary>
/// Everything the "Subjects &amp; Teachers" screen needs for one class: the school's subject
/// list with the class's picks, and the teacher grid across its sections.
/// </summary>
public record ClassCurriculumDto(
    long ClassId,
    string ClassName,
    string? AcademicYear,
    IReadOnlyList<ClassSubjectOptionDto> Subjects,
    IReadOnlyList<AssignmentRowDto> Grid);

public class SetClassSubjectsDto
{
    public IReadOnlyList<long> SubjectIds { get; set; } = Array.Empty<long>();
}

public class SaveAssignmentDto
{
    public long ClassId { get; set; }
    public long SectionId { get; set; }
    public long SubjectId { get; set; }
    /// <summary>Null clears the slot.</summary>
    public long? StaffId { get; set; }
}
