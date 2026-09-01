using SchoolErp.Application.DTOs.Notifications;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>The in-app bell feed: read by the signed-in user, written by other services.</summary>
public interface INotificationCenter
{
    Task<NotificationFeedDto> GetFeedAsync(CancellationToken ct = default);
    Task MarkReadAsync(long id, CancellationToken ct = default);
    Task MarkAllReadAsync(CancellationToken ct = default);

    /// <summary>Notifies every active user of a role — school-scoped, or platform staff when schoolId is null.</summary>
    Task NotifyRoleAsync(long? schoolId, string userType, string title, string? body, string type,
        string? refTable = null, long? refId = null, CancellationToken ct = default);
}
