namespace SchoolErp.Application.DTOs.Admin;

/// <summary>One distance band as the screen shows it. <paramref name="FromKm"/> is derived from
/// the band below so the table can read "3 – 6 km" without the client re-deriving it.</summary>
public record TransportSlabDto(long Id, decimal FromKm, decimal UpToKm, decimal Amount, int Riders);

public class SaveTransportSlabDto
{
    public decimal UpToKm { get; set; }
    public decimal Amount { get; set; }
}

/// <summary>
/// The whole band set, replaced in one call. Bands are meaningless individually — moving the
/// 6 km ceiling to 7 changes which band a 6.5 km student is in — so they are saved together
/// rather than one row at a time.
/// </summary>
public class SaveTransportSlabsDto
{
    public long? AcademicYearId { get; set; }
    public List<SaveTransportSlabDto> Slabs { get; set; } = new();
}

/// <summary>One student on the assignment list, with the amount their distance currently earns.</summary>
public record TransportStudentDto(
    long StudentId,
    string Name,
    string AdmissionNo,
    string? ClassName,
    string? SectionName,
    bool UsesTransport,
    decimal? DistanceKm,
    string? PickupPoint,
    decimal? AmountOverride,
    string? Note,
    /// <summary>What this student will actually be billed; 0 when they are not billable.</summary>
    decimal Amount,
    /// <summary>priced | not_riding | no_distance | beyond_slabs | no_slabs.</summary>
    string Status,
    /// <summary>The ceiling of the band that priced them, or null on an override.</summary>
    decimal? MatchedSlabKm);

public class SaveTransportStudentDto
{
    public long StudentId { get; set; }
    public bool UsesTransport { get; set; }
    public decimal? DistanceKm { get; set; }
    public string? PickupPoint { get; set; }
    public decimal? AmountOverride { get; set; }
    public string? Note { get; set; }
}

public class SaveTransportStudentsDto
{
    public List<SaveTransportStudentDto> Students { get; set; } = new();
}

/// <summary>Counts for the header, so the admin can see at a glance what still needs attention.</summary>
public record TransportSummaryDto(
    int Riders,
    int NotRiding,
    int NeedsDistance,
    int BeyondSlabs,
    decimal MonthlyTotal);

/// <summary>
/// Everything the Transport Fee screen draws: which head is distance-priced, the bands for the
/// chosen year, and one row per student with the amount those bands produce.
/// </summary>
public record TransportGridDto(
    long? AcademicYearId,
    string? AcademicYearName,
    long? FeeHeadId,
    string? FeeHeadName,
    string? FeeHeadFrequency,
    IReadOnlyList<TransportSlabDto> Slabs,
    IReadOnlyList<TransportStudentDto> Students,
    TransportSummaryDto Summary);
