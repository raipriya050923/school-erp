namespace SchoolErp.Domain.Entities;

/// <summary>A subject a school teaches. Maps to `subjects`, unique per (school_id, name).</summary>
public class Subject
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Code { get; set; }
    public string SubjectType { get; set; } = "theory";   // theory | practical | both
    public bool IsActive { get; set; } = true;
}
