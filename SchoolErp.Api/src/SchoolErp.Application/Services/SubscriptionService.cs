using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

public class SubscriptionService : ISubscriptionService
{
    private readonly ISubscriptionRepository _subs;

    public SubscriptionService(ISubscriptionRepository subs) => _subs = subs;

    public Task<IReadOnlyList<SchoolSubscription>> ListAsync(string? status, long? planId, CancellationToken ct = default)
        => _subs.GetAllAsync(status, planId, ct);
}
