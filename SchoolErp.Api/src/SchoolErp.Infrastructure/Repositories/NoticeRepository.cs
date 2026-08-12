using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class NoticeRepository : INoticeRepository
{
    private readonly IDbConnectionFactory _factory;
    public NoticeRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<Notice>> GetAllAsync(long schoolId, int? take, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = @"SELECT id, school_id, title, body, audience, publish_date, expiry_date, is_published, created_by, created_at
                    FROM notices WHERE school_id=@sid AND is_published=1
                    ORDER BY publish_date DESC, id DESC";
        if (take.HasValue) sql += $" LIMIT {take.Value}";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@sid", schoolId));
    }

    public async Task<long> CreateAsync(Notice n, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO notices (school_id, title, body, audience, publish_date, is_published, created_by, created_at)
            VALUES (@sid, @title, @body, @audience, CURDATE(), 1, @by, NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", n.SchoolId), ("@title", n.Title), ("@body", n.Body),
            ("@audience", n.Audience), ("@by", n.CreatedBy));
    }

    private static Notice Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        Title = r.GetString("title"),
        Body = r.GetString("body"),
        Audience = r.GetString("audience"),
        PublishDate = r.GetDate("publish_date"),
        ExpiryDate = r.GetDateOrNull("expiry_date"),
        IsPublished = r.GetBool("is_published"),
        CreatedBy = r.GetLong("created_by"),
        CreatedAt = r.GetDate("created_at"),
    };
}
