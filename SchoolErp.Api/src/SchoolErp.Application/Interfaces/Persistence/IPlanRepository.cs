using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IPlanRepository
{
    Task<IReadOnlyList<SubscriptionPlan>> GetAllAsync(CancellationToken ct = default);
    Task<SubscriptionPlan?> GetByIdAsync(long id, CancellationToken ct = default);
    Task<long> CreateAsync(SubscriptionPlan plan, CancellationToken ct = default);
    Task UpdateAsync(SubscriptionPlan plan, CancellationToken ct = default);
    Task SetActiveAsync(long id, bool isActive, CancellationToken ct = default);
    Task<bool> ExistsByNameAsync(string name, long? excludeId, CancellationToken ct = default);
    Task<int> GetSubscriberCountAsync(long planId, CancellationToken ct = default);
}
