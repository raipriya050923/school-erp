using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class NotificationRepository : INotificationRepository
{
    private readonly IDbConnectionFactory _factory;
    public NotificationRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = "id, school_id, user_id, title, body, type, ref_table, ref_id, read_at, created_at";

    public async Task<IReadOnlyList<Notification>> GetForUserAsync(long userId, int take, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM notifications WHERE user_id=@uid ORDER BY created_at DESC, id DESC LIMIT @take";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@uid", userId), ("@take", take));
    }

    public async Task<int> UnreadCountAsync(long userId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM notifications WHERE user_id=@uid AND read_at IS NULL", ct, ("@uid", userId));
    }

    /// <summary>Scoped by user_id as well as id so one user can never mark another's row read.</summary>
    public async Task MarkReadAsync(long userId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE notifications SET read_at=NOW() WHERE id=@id AND user_id=@uid AND read_at IS NULL", ct,
            ("@id", id), ("@uid", userId));
    }

    public async Task MarkAllReadAsync(long userId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE notifications SET read_at=NOW() WHERE user_id=@uid AND read_at IS NULL", ct, ("@uid", userId));
    }

    public async Task AddForUserAsync(long userId, long? schoolId, Notification n, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO notifications (school_id, user_id, title, body, type, ref_table, ref_id, created_at)
            VALUES (@sid, @uid, @title, @body, @type, @reftable, @refid, NOW())";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@sid", (object?)schoolId), ("@uid", userId), ("@title", n.Title), ("@body", n.Body),
            ("@type", n.Type), ("@reftable", n.RefTable), ("@refid", n.RefId));
    }

    /// <summary>
    /// One INSERT…SELECT rather than a round-trip per recipient: a school can have several admins
    /// and the platform several super admins. A null <paramref name="schoolId"/> targets platform
    /// staff, whose users rows carry no school.
    /// </summary>
    public async Task AddForRoleAsync(long? schoolId, string userType, Notification n, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var scope = schoolId.HasValue ? "u.school_id = @sid" : "u.school_id IS NULL";
        var sql = $@"
            INSERT INTO notifications (school_id, user_id, title, body, type, ref_table, ref_id, created_at)
            SELECT @sid, u.id, @title, @body, @type, @reftable, @refid, NOW()
            FROM users u
            WHERE u.user_type=@utype AND u.is_active=1 AND {scope}";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@sid", schoolId), ("@utype", userType), ("@title", n.Title), ("@body", n.Body),
            ("@type", n.Type), ("@reftable", n.RefTable), ("@refid", n.RefId));
    }

    private static Notification Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLongOrNull("school_id"),
        UserId = r.GetLong("user_id"),
        Title = r.GetString("title"),
        Body = r.GetStringOrNull("body"),
        Type = r.GetString("type"),
        RefTable = r.GetStringOrNull("ref_table"),
        RefId = r.GetLongOrNull("ref_id"),
        ReadAt = r.GetDateOrNull("read_at"),
        CreatedAt = r.GetDate("created_at"),
    };
}
