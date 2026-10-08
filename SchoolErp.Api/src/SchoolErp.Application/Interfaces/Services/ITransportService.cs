using SchoolErp.Application.DTOs.Admin;

namespace SchoolErp.Application.Interfaces.Services;

public interface ITransportService
{
    /// <summary>The bands, the riders, and what each rider's distance currently earns.</summary>
    Task<TransportGridDto> GridAsync(long? academicYearId, CancellationToken ct = default);
    /// <summary>Replaces the band set for one academic year.</summary>
    Task SaveSlabsAsync(SaveTransportSlabsDto dto, CancellationToken ct = default);
    /// <summary>Writes transport details for the students named, leaving every other student alone.</summary>
    Task<int> SaveStudentsAsync(SaveTransportStudentsDto dto, CancellationToken ct = default);
    /// <summary>Copies a band set into another year, leaving bands the target already has.</summary>
    Task<int> CopySlabsAsync(CopyFeeStructureDto dto, CancellationToken ct = default);
}
