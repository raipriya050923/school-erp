namespace SchoolErp.Domain.Entities;

/// <summary>A section a teacher handles (for the Teacher "My Classes" screen).</summary>
public class TeacherClassRow
{
    public long SectionId { get; set; }
    public string ClassName { get; set; } = string.Empty;
    public string SectionName { get; set; } = string.Empty;
    public string? Room { get; set; }
    public int StudentCount { get; set; }
}

/// <summary>
/// One subject a teacher is assigned to teach in one section, for the current academic year.
/// This — not who the class teacher is — is what decides whose marks a teacher may enter.
/// </summary>
public class TeacherAssignmentRow
{
    public long SectionId { get; set; }
    public string ClassName { get; set; } = string.Empty;
    public string SectionName { get; set; } = string.Empty;
    public long SubjectId { get; set; }
    public string Subject { get; set; } = string.Empty;
    public int StudentCount { get; set; }
}

/// <summary>A homework assignment (demo table `teacher_homework`).</summary>
public class TeacherHomework
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long TeacherStaffId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Subject { get; set; }
    public string? ClassLabel { get; set; }
    public DateTime? AssignedDate { get; set; }
    public DateTime? DueDate { get; set; }
    public int SubmittedCount { get; set; }
    public int TotalCount { get; set; }
    public string Status { get; set; } = "open";
    public DateTime CreatedAt { get; set; }
}

/// <summary>Who owns a subject in one section — used to name the teacher a missing mark is owed by.</summary>
public class SubjectTeacherRow
{
    public string Subject { get; set; } = string.Empty;
    public string? TeacherName { get; set; }
}
