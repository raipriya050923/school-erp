using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface INotificationRepository
{
    Task<IReadOnlyList<Notification>> GetForUserAsync(long userId, int take, CancellationToken ct = default);
    Task<int> UnreadCountAsync(long userId, CancellationToken ct = default);
    Task MarkReadAsync(long userId, long id, CancellationToken ct = default);
    Task MarkAllReadAsync(long userId, CancellationToken ct = default);
    /// <summary>Adds one notification for one account — the reply to something they did.</summary>
    Task AddForUserAsync(long userId, long? schoolId, Notification template, CancellationToken ct = default);
    /// <summary>Adds one notification per user of the given type in a school (school-scoped fan-out).</summary>
    Task AddForRoleAsync(long? schoolId, string userType, Notification template, CancellationToken ct = default);
}
