using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class TicketRepository : ITicketRepository
{
    private readonly IDbConnectionFactory _factory;
    public TicketRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<SupportTicket>> GetAllAsync(string? status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = @"
            SELECT t.id, t.school_id, t.raised_by, t.assigned_to, t.ticket_no, t.subject,
                   t.description, t.priority, t.status, t.closed_at, t.created_at, t.updated_at,
                   s.name AS school_name, u.full_name AS raised_by_name
            FROM support_tickets t
            JOIN schools s ON s.id = t.school_id
            LEFT JOIN users u ON u.id = t.raised_by
            WHERE 1=1";
        var ps = new List<(string, object?)>();
        if (!string.IsNullOrWhiteSpace(status)) { sql += " AND t.status=@st"; ps.Add(("@st", status)); }
        sql += " ORDER BY t.created_at DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<SupportTicket?> GetByIdAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT t.id, t.school_id, t.raised_by, t.assigned_to, t.ticket_no, t.subject,
                   t.description, t.priority, t.status, t.closed_at, t.created_at, t.updated_at,
                   s.name AS school_name, u.full_name AS raised_by_name
            FROM support_tickets t
            JOIN schools s ON s.id = t.school_id
            LEFT JOIN users u ON u.id = t.raised_by
            WHERE t.id=@id;";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id));
    }

    public async Task<IReadOnlyList<SupportTicketReply>> GetRepliesAsync(long ticketId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT r.id, r.ticket_id, r.user_id, r.message, r.attachment_url, r.created_at,
                   u.full_name AS author_name, u.user_type AS author_type
            FROM support_ticket_replies r
            LEFT JOIN users u ON u.id = r.user_id
            WHERE r.ticket_id=@id
            ORDER BY r.created_at ASC;";
        return await DbHelper.QueryAsync(conn, sql, MapReply, ct, ("@id", ticketId));
    }

    public async Task UpdateStatusAsync(long id, string status, DateTime? closedAt, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE support_tickets SET status=@st, closed_at=@closed, updated_at=NOW() WHERE id=@id", ct,
            ("@st", status), ("@closed", (object?)closedAt), ("@id", id));
    }

    public async Task<long> AddReplyAsync(SupportTicketReply reply, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO support_ticket_replies (ticket_id, user_id, message, attachment_url, created_at)
            VALUES (@tid, @uid, @msg, @att, NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@tid", reply.TicketId), ("@uid", reply.UserId),
            ("@msg", reply.Message), ("@att", reply.AttachmentUrl));
    }

    public async Task<int> GetReplyCountAsync(long ticketId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM support_ticket_replies WHERE ticket_id=@id", ct, ("@id", ticketId));
    }

    private static SupportTicket Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        RaisedBy = r.GetLong("raised_by"),
        AssignedTo = r.GetLongOrNull("assigned_to"),
        TicketNo = r.GetString("ticket_no"),
        Subject = r.GetString("subject"),
        Description = r.GetString("description"),
        Priority = r.GetString("priority"),
        Status = r.GetString("status"),
        ClosedAt = r.GetDateOrNull("closed_at"),
        CreatedAt = r.GetDate("created_at"),
        UpdatedAt = r.GetDate("updated_at"),
        SchoolName = r.GetStringOrNull("school_name"),
        RaisedByName = r.GetStringOrNull("raised_by_name"),
    };

    private static SupportTicketReply MapReply(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        TicketId = r.GetLong("ticket_id"),
        UserId = r.GetLong("user_id"),
        Message = r.GetString("message"),
        AttachmentUrl = r.GetStringOrNull("attachment_url"),
        CreatedAt = r.GetDate("created_at"),
        AuthorName = r.GetStringOrNull("author_name"),
        AuthorType = r.GetStringOrNull("author_type"),
    };
}
