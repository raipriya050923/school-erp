using SchoolErp.Application.DTOs.Billing;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>Plan entitlements for one school: seats, expiry and access.</summary>
public interface ISubscriptionGuard
{
    Task<SubscriptionStatusDto> GetStatusAsync(long schoolId, CancellationToken ct = default);

    /// <summary>Throws when the school may not be signed into at all.</summary>
    Task EnsureUsableAsync(long schoolId, CancellationToken ct = default);

    /// <summary>Throws when admitting another student would exceed the plan.</summary>
    Task EnsureCanAdmitStudentAsync(long schoolId, CancellationToken ct = default);
}
