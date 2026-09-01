using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class NoticeRepository : INoticeRepository
{
    private readonly IDbConnectionFactory _factory;
    public NoticeRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string SelectJoined = @"
        SELECT n.id, n.school_id, n.title, n.body, n.audience, n.publish_date, n.expiry_date,
               n.is_published, n.created_by, n.created_at,
               (SELECT u.full_name FROM users u WHERE u.id = n.created_by) AS created_by_name
        FROM notices n";

    public async Task<IReadOnlyList<Notice>> GetAllAsync(long schoolId, int? take, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"{SelectJoined}
                     WHERE n.school_id=@sid AND n.is_published=1
                     ORDER BY n.publish_date DESC, n.id DESC";
        if (take.HasValue) sql += $" LIMIT {take.Value}";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@sid", schoolId));
    }

    public async Task<Notice?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $"{SelectJoined} WHERE n.id=@id AND n.school_id=@sid", Map, ct,
            ("@id", id), ("@sid", schoolId));
    }

    public async Task UpdateAsync(Notice n, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"UPDATE notices SET title=@title, body=@body, audience=@audience
              WHERE id=@id AND school_id=@sid", ct,
            ("@title", n.Title), ("@body", n.Body), ("@audience", n.Audience),
            ("@id", n.Id), ("@sid", n.SchoolId));
    }

    public async Task DeleteAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "DELETE FROM notices WHERE id=@id AND school_id=@sid", ct,
            ("@id", id), ("@sid", schoolId));
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
        CreatedByName = r.GetStringOrNull("created_by_name"),
    };
}
