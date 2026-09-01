namespace SchoolErp.Domain.Entities;

/// <summary>
/// A school session. Maps to `academic_years`. Exactly one row per school carries
/// <see cref="IsCurrent"/>, and everything year-scoped (class subjects, teacher assignments)
/// resolves through it.
/// </summary>
public class AcademicYear
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public bool IsCurrent { get; set; }
    public DateTime CreatedAt { get; set; }
}
