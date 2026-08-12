namespace SchoolErp.Domain.Entities;

/// <summary>A class/grade. Maps to `classes`.</summary>
public class SchoolClass
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string Name { get; set; } = string.Empty;
    public short? NumericLevel { get; set; }
    public bool IsActive { get; set; } = true;
    public List<ClassSection> Sections { get; set; } = new();
}

/// <summary>A section within a class. Maps to `sections`.</summary>
public class ClassSection
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long ClassId { get; set; }
    public string Name { get; set; } = string.Empty;
    public short? Capacity { get; set; }
    public string? Teacher { get; set; }   // display name of class teacher
    public int StudentCount { get; set; }
    public bool IsActive { get; set; } = true;
}
