namespace SchoolErp.Application.DTOs.Notifications;

public record NotificationDto(long Id, string Title, string? Body, string Type, bool IsUnread, DateTime CreatedAt);

public record NotificationFeedDto(int UnreadCount, IReadOnlyList<NotificationDto> Items);
