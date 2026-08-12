namespace SchoolErp.Application.DTOs.Admin;

public record SectionDto(long Id, long ClassId, string Name, string? Teacher, int StudentCount);

public record ClassDto(long Id, string Name, IReadOnlyList<SectionDto> Sections);

public class CreateClassDto
{
    public string Name { get; set; } = string.Empty;
    public string? SectionName { get; set; }
    public string? Teacher { get; set; }
}

public record RenameClassDto(string Name);

public class SaveSectionDto
{
    public long ClassId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Teacher { get; set; }
}
