namespace SchoolErp.Application.DTOs.Admin;

/// <summary>A charge the school levies. <paramref name="InUse"/> counts the classes priced for it.</summary>
public record FeeHeadDto(long Id, string Name, string? Description, string Frequency, bool IsRefundable, bool IsActive, int InUse);

public class SaveFeeHeadDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    /// <summary>one_time | monthly | quarterly | half_yearly | yearly.</summary>
    public string Frequency { get; set; } = "monthly";
    public bool IsRefundable { get; set; }
}

public record FeeStructureClassDto(long ClassId, string ClassName);
/// <summary>One priced pair. Unpriced pairs are simply absent, which the grid renders as blank.</summary>
public record FeeStructureCellDto(long ClassId, long HeadId, decimal Amount);

/// <summary>
/// Everything the Fee Structure screen draws: the year being priced, the classes down the side,
/// the active heads across the top, and the amounts that have been set.
/// <paramref name="MonthlyTotals"/> is per class — what one monthly invoice will come to.
/// </summary>
public record FeeStructureGridDto(
    long? AcademicYearId,
    string? AcademicYearName,
    IReadOnlyList<FeeStructureClassDto> Classes,
    IReadOnlyList<FeeHeadDto> Heads,
    IReadOnlyList<FeeStructureCellDto> Cells,
    IReadOnlyDictionary<string, decimal> MonthlyTotals);

public class SaveFeeStructureDto
{
    /// <summary>Defaults to the current academic year when omitted.</summary>
    public long? AcademicYearId { get; set; }
    public List<FeeStructureCellEntry> Cells { get; set; } = new();
}
public class FeeStructureCellEntry
{
    public long ClassId { get; set; }
    public long HeadId { get; set; }
    /// <summary>Zero clears the price — the class stops being billed for that head.</summary>
    public decimal Amount { get; set; }
}

public class CopyFeeStructureDto
{
    public long FromAcademicYearId { get; set; }
    public long ToAcademicYearId { get; set; }
}
