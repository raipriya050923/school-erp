using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Tickets;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

public class TicketService : ITicketService
{
    private static readonly string[] ValidStatuses =
        { "open", "in_progress", "waiting", "resolved", "closed" };

    private readonly ITicketRepository _tickets;
    private readonly INotificationSender _notifier;

    public TicketService(ITicketRepository tickets, INotificationSender notifier)
    {
        _tickets = tickets;
        _notifier = notifier;
    }

    public async Task<IReadOnlyList<TicketListItemDto>> ListAsync(string? status, CancellationToken ct = default)
    {
        var rows = await _tickets.GetAllAsync(status, ct);
        var list = new List<TicketListItemDto>(rows.Count);
        foreach (var t in rows)
        {
            var count = await _tickets.GetReplyCountAsync(t.Id, ct);
            list.Add(new TicketListItemDto(t.Id, t.TicketNo, t.SchoolId, t.SchoolName ?? "",
                t.RaisedByName ?? "", t.Subject, t.Priority, t.Status, count, t.CreatedAt));
        }
        return list;
    }

    public async Task<TicketDetailDto?> GetAsync(long id, CancellationToken ct = default)
    {
        var t = await _tickets.GetByIdAsync(id, ct);
        if (t is null) return null;
        var replies = await _tickets.GetRepliesAsync(id, ct);
        var comments = replies.Select(ToReplyDto).ToList();
        return new TicketDetailDto(t.Id, t.TicketNo, t.SchoolName ?? "", t.RaisedByName ?? "",
            t.Subject, t.Description, t.Priority, t.Status, t.CreatedAt, comments);
    }

    public async Task ChangeStatusAsync(long id, string status, CancellationToken ct = default)
    {
        if (!ValidStatuses.Contains(status))
            throw new ValidationException($"Invalid status '{status}'.");
        _ = await _tickets.GetByIdAsync(id, ct) ?? throw new NotFoundException($"Ticket {id} not found.");
        var closedAt = status is "resolved" or "closed" ? DateTime.UtcNow : (DateTime?)null;
        await _tickets.UpdateStatusAsync(id, status, closedAt, ct);
    }

    public async Task ResolveAsync(long id, ResolveTicketDto dto, long actingUserId, CancellationToken ct = default)
    {
        var t = await _tickets.GetByIdAsync(id, ct) ?? throw new NotFoundException($"Ticket {id} not found.");
        if (string.IsNullOrWhiteSpace(dto.ResolutionNote))
            throw new ValidationException("A resolution note is required.");

        await _tickets.AddReplyAsync(new SupportTicketReply
        {
            TicketId = id,
            UserId = actingUserId,
            Message = dto.ResolutionNote.Trim(),
            CreatedAt = DateTime.UtcNow,
        }, ct);
        await _tickets.UpdateStatusAsync(id, "resolved", DateTime.UtcNow, ct);

        if (dto.NotifySchool)
        {
            var email = $"admin@{(t.SchoolName ?? "school").ToLowerInvariant().Replace(' ', '-')}.edu.np";
            await _notifier.SendEmailAsync(email,
                $"Your ticket {t.TicketNo} has been resolved",
                dto.ResolutionNote.Trim(), ct);
        }
    }

    public async Task<TicketReplyDto> AddCommentAsync(long id, AddCommentDto dto, CancellationToken ct = default)
    {
        _ = await _tickets.GetByIdAsync(id, ct) ?? throw new NotFoundException($"Ticket {id} not found.");
        if (string.IsNullOrWhiteSpace(dto.Message))
            throw new ValidationException("Comment message is required.");

        var reply = new SupportTicketReply
        {
            TicketId = id,
            UserId = dto.UserId,
            Message = dto.Message.Trim(),
            CreatedAt = DateTime.UtcNow,
        };
        reply.Id = await _tickets.AddReplyAsync(reply, ct);
        var saved = (await _tickets.GetRepliesAsync(id, ct)).FirstOrDefault(r => r.Id == reply.Id) ?? reply;
        return ToReplyDto(saved);
    }

    private static TicketReplyDto ToReplyDto(SupportTicketReply r)
    {
        var side = r.AuthorType is "super_admin" or "platform_support" ? "platform" : "school";
        return new TicketReplyDto(r.Id, r.UserId, r.AuthorName ?? "User", side, r.Message, r.CreatedAt);
    }
}
