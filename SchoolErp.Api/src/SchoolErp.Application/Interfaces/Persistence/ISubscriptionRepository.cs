using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ISubscriptionRepository
{
    Task<IReadOnlyList<SchoolSubscription>> GetAllAsync(string? status, long? planId, CancellationToken ct = default);
    Task<int> CountByStatusAsync(string status, CancellationToken ct = default);
    Task<decimal> GetMonthlyRecurringRevenueAsync(CancellationToken ct = default);
}
