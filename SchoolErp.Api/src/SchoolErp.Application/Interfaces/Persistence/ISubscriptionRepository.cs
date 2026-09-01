using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ISubscriptionRepository
{
    Task<IReadOnlyList<SchoolSubscription>> GetAllAsync(string? status, long? planId, CancellationToken ct = default);
    Task<int> CountByStatusAsync(string status, CancellationToken ct = default);
    Task<decimal> GetMonthlyRecurringRevenueAsync(CancellationToken ct = default);
    Task<long> CreateAsync(SchoolSubscription subscription, CancellationToken ct = default);
    /// <summary>The school's newest live subscription, or null if it has never had one.</summary>
    Task<SchoolSubscription?> GetCurrentBySchoolAsync(long schoolId, CancellationToken ct = default);
    /// <summary>The school's newest subscription whatever its status — used to spot expired ones.</summary>
    Task<SchoolSubscription?> GetLatestBySchoolAsync(long schoolId, CancellationToken ct = default);
    Task<SchoolSubscription?> GetByIdAsync(long id, CancellationToken ct = default);
    /// <summary>Marks a subscription paid-up and moves it onto the given period.</summary>
    Task ActivateAsync(long id, DateTime startDate, DateTime endDate, CancellationToken ct = default);
    /// <summary>Switches an existing subscription to a different plan / cycle, re-locking the price.</summary>
    Task UpdatePlanAsync(long id, long planId, string billingCycle, decimal price, CancellationToken ct = default);
    /// <summary>Current plan name per school id, for schools that have a live subscription.</summary>
    Task<IReadOnlyDictionary<long, string>> GetCurrentPlanNamesAsync(CancellationToken ct = default);
}
