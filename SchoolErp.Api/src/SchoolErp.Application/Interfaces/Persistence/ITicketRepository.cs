using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ITicketRepository
{
    Task<IReadOnlyList<SupportTicket>> GetAllAsync(string? status, CancellationToken ct = default);
    Task<SupportTicket?> GetByIdAsync(long id, CancellationToken ct = default);
    Task<IReadOnlyList<SupportTicketReply>> GetRepliesAsync(long ticketId, CancellationToken ct = default);
    Task UpdateStatusAsync(long id, string status, DateTime? closedAt, CancellationToken ct = default);
    Task<long> AddReplyAsync(SupportTicketReply reply, CancellationToken ct = default);
    Task<int> GetReplyCountAsync(long ticketId, CancellationToken ct = default);
}
