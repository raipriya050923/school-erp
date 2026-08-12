using SchoolErp.Application.DTOs.Tickets;

namespace SchoolErp.Application.Interfaces.Services;

public interface ITicketService
{
    Task<IReadOnlyList<TicketListItemDto>> ListAsync(string? status, CancellationToken ct = default);
    Task<TicketDetailDto?> GetAsync(long id, CancellationToken ct = default);
    Task ChangeStatusAsync(long id, string status, CancellationToken ct = default);
    Task ResolveAsync(long id, ResolveTicketDto dto, long actingUserId, CancellationToken ct = default);
    Task<TicketReplyDto> AddCommentAsync(long id, AddCommentDto dto, CancellationToken ct = default);
}
