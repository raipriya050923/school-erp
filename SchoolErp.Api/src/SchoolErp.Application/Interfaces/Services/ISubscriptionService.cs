using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Services;

public interface ISubscriptionService
{
    Task<IReadOnlyList<SchoolSubscription>> ListAsync(string? status, long? planId, CancellationToken ct = default);
}
