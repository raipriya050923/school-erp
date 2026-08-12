using SchoolErp.Application.DTOs.Dashboard;

namespace SchoolErp.Application.Interfaces.Services;

public interface IDashboardService
{
    Task<DashboardStatsDto> GetStatsAsync(CancellationToken ct = default);
}
