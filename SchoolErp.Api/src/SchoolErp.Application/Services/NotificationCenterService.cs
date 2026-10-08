using SchoolErp.Application.DTOs.Notifications;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

/// <summary>
/// Reads the signed-in user's bell feed and lets other services push into it. Everything is
/// scoped by the token's user id, so a caller can only ever see or clear their own rows.
/// </summary>
public class NotificationCenterService : INotificationCenter
{
    private const int FeedSize = 15;
    private readonly INotificationRepository _repo;
    private readonly ICurrentUser _user;

    public NotificationCenterService(INotificationRepository repo, ICurrentUser user)
    {
        _repo = repo;
        _user = user;
    }

    public async Task<NotificationFeedDto> GetFeedAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetForUserAsync(_user.UserId, FeedSize, ct);
        var unread = await _repo.UnreadCountAsync(_user.UserId, ct);
        return new NotificationFeedDto(unread, rows.Select(ToDto).ToList());
    }

    public Task MarkReadAsync(long id, CancellationToken ct = default)
        => _repo.MarkReadAsync(_user.UserId, id, ct);

    public Task MarkAllReadAsync(CancellationToken ct = default)
        => _repo.MarkAllReadAsync(_user.UserId, ct);

    /// <summary>
    /// Fan-out helper for other services. Failures are swallowed on purpose: a notification is a
    /// side effect, and losing one must never fail the admission or payment that triggered it.
    /// </summary>
    public async Task NotifyRoleAsync(long? schoolId, string userType, string title, string? body,
        string type, string? refTable = null, long? refId = null, CancellationToken ct = default)
    {
        try
        {
            await _repo.AddForRoleAsync(schoolId, userType, new Notification
            {
                Title = title, Body = body, Type = type, RefTable = refTable, RefId = refId,
            }, ct);
        }
        catch
        {
            // deliberately ignored — see summary
        }
    }

    /// <summary>
    /// Same contract as <see cref="NotifyRoleAsync"/>, aimed at one account: a failure here must
    /// never fail the review that prompted it.
    /// </summary>
    public async Task NotifyUserAsync(long userId, long? schoolId, string title, string? body,
        string type, string? refTable = null, long? refId = null, CancellationToken ct = default)
    {
        try
        {
            await _repo.AddForUserAsync(userId, schoolId, new Notification
            {
                Title = title, Body = body, Type = type, RefTable = refTable, RefId = refId,
            }, ct);
        }
        catch
        {
            // deliberately ignored — see summary
        }
    }

    private static NotificationDto ToDto(Notification n) =>
        new(n.Id, n.Title, n.Body, n.Type, n.ReadAt is null, n.CreatedAt);
}
