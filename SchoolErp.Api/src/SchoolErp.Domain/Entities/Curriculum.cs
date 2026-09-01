namespace SchoolErp.Domain.Entities;

/// <summary>
/// A subject a class studies in an academic year. Maps to `class_subjects`,
/// unique per (academic_year_id, class_id, subject_id).
/// </summary>
public class ClassSubject
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long AcademicYearId { get; set; }
    public long ClassId { get; set; }
    public long SubjectId { get; set; }
    public bool IsOptional { get; set; }
    public short? FullMarks { get; set; }
    public short? PassMarks { get; set; }

    public string? SubjectName { get; set; }
}

/// <summary>
/// The teacher who teaches one subject to one section in an academic year. Maps to
/// `teacher_assignments`. This is the link the class teacher (sections.class_teacher_id)
/// does not provide: a section has one class teacher but many subject teachers.
/// </summary>
public class TeacherAssignment
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long AcademicYearId { get; set; }
    public long StaffId { get; set; }
    public long ClassId { get; set; }
    public long SectionId { get; set; }
    public long SubjectId { get; set; }

    public string? TeacherName { get; set; }
    public string? SubjectName { get; set; }
    public string? SectionName { get; set; }
    public string? ClassName { get; set; }
}
