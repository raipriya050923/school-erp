using SchoolErp.Application.DTOs.Dashboard;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services;

public class DashboardService : IDashboardService
{
    private readonly ISchoolRepository _schools;
    private readonly ISubscriptionRepository _subs;
    private readonly IBillingRepository _billing;

    public DashboardService(ISchoolRepository schools, ISubscriptionRepository subs, IBillingRepository billing)
    {
        _schools = schools;
        _subs = subs;
        _billing = billing;
    }

    public async Task<DashboardStatsDto> GetStatsAsync(CancellationToken ct = default)
    {
        var totalSchools = await _schools.CountAsync(ct);
        var active = await _subs.CountByStatusAsync("active", ct);
        var trial = await _subs.CountByStatusAsync("trial", ct);
        var mrr = await _subs.GetMonthlyRecurringRevenueAsync(ct);
        var openTickets = await _billing.OpenTicketsCountAsync(ct);
        return new DashboardStatsDto(totalSchools, active, trial, mrr, openTickets);
    }
}
