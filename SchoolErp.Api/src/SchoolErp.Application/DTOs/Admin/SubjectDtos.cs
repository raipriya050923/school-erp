namespace SchoolErp.Application.DTOs.Admin;

public record SubjectDto(long Id, string Name, string? Code, string SubjectType, bool IsActive);

public class SaveSubjectDto
{
    public string Name { get; set; } = string.Empty;
    public string? Code { get; set; }
    public string SubjectType { get; set; } = "theory";   // theory | practical | both
}
