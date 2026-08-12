using SchoolErp.Application.DTOs.Plans;

namespace SchoolErp.Application.Interfaces.Services;

public interface IPlanService
{
    Task<IReadOnlyList<PlanDto>> ListAsync(CancellationToken ct = default);
    Task<PlanDto?> GetAsync(long id, CancellationToken ct = default);
    Task<long> CreateAsync(CreatePlanDto dto, CancellationToken ct = default);
    Task UpdateAsync(long id, UpdatePlanDto dto, CancellationToken ct = default);
    Task SetActiveAsync(long id, bool isActive, CancellationToken ct = default);
}
