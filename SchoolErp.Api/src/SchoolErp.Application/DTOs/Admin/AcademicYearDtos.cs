namespace SchoolErp.Application.DTOs.Admin;

public record AcademicYearDto(long Id, string Name, DateTime StartDate, DateTime EndDate,
    bool IsCurrent, int UsageCount);

public class SaveAcademicYearDto
{
    public string Name { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
}
