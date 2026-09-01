using SchoolErp.Application.DTOs.Admin;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>
/// The fee heads a school levies and what each class pays for them. This is where invoice
/// amounts come from — the invoice run reads the structure rather than any built-in rate.
/// </summary>
public interface IFeeStructureService
{
    Task<IReadOnlyList<FeeHeadDto>> ListHeadsAsync(CancellationToken ct = default);
    Task<long> CreateHeadAsync(SaveFeeHeadDto dto, CancellationToken ct = default);
    Task UpdateHeadAsync(long id, SaveFeeHeadDto dto, CancellationToken ct = default);
    Task SetHeadActiveAsync(long id, bool isActive, CancellationToken ct = default);

    /// <summary>The pricing grid for one academic year, or the current one when null.</summary>
    Task<FeeStructureGridDto> GridAsync(long? academicYearId, CancellationToken ct = default);
    Task SaveGridAsync(SaveFeeStructureDto dto, CancellationToken ct = default);
    /// <summary>Number of prices copied across.</summary>
    Task<int> CopyYearAsync(CopyFeeStructureDto dto, CancellationToken ct = default);
}
