using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class GuardianRepository : IGuardianRepository
{
    private readonly IDbConnectionFactory _factory;
    public GuardianRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = @"
        g.id, g.school_id, g.user_id, g.first_name, g.last_name, g.relation,
        g.email, g.phone, g.occupation, g.address, u.username";

    public async Task<Guardian?> GetForStudentAsync(long schoolId, long studentId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // The primary guardian first, so a student with several contacts resolves
        // to the one the school nominated rather than whichever was added first.
        var sql = $@"
            SELECT {Cols}
            FROM student_guardians sg
            JOIN guardians g ON g.id = sg.guardian_id
            LEFT JOIN users u ON u.id = g.user_id AND u.deleted_at IS NULL
            WHERE sg.student_id = @sid AND g.school_id = @school
            ORDER BY sg.is_primary DESC, g.id
            LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct,
            ("@sid", studentId), ("@school", schoolId));
    }

    public async Task<long> CreateAsync(Guardian g, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO guardians (school_id, user_id, first_name, last_name, relation, email, phone, occupation, address)
            VALUES (@school, @uid, @first, @last, @rel, @email, @phone, @occ, @addr)";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@school", g.SchoolId), ("@uid", g.UserId), ("@first", g.FirstName), ("@last", g.LastName),
            ("@rel", g.Relation), ("@email", g.Email), ("@phone", g.Phone),
            ("@occ", g.Occupation), ("@addr", g.Address));
    }

    public async Task LinkAsync(long studentId, long guardianId, bool isPrimary, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // (student_id, guardian_id) is the primary key, so re-linking is a no-op
        // rather than a duplicate-key failure.
        const string sql = @"
            INSERT INTO student_guardians (student_id, guardian_id, is_primary)
            VALUES (@sid, @gid, @primary)
            ON DUPLICATE KEY UPDATE is_primary = VALUES(is_primary)";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@sid", studentId), ("@gid", guardianId), ("@primary", isPrimary ? 1 : 0));
    }

    public async Task SetUserIdAsync(long schoolId, long guardianId, long userId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE guardians SET user_id=@uid WHERE id=@id AND school_id=@school", ct,
            ("@uid", userId), ("@id", guardianId), ("@school", schoolId));
    }

    public async Task<IReadOnlyList<long>> GetStudentIdsWithParentLoginAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT DISTINCT sg.student_id
            FROM student_guardians sg
            JOIN guardians g ON g.id = sg.guardian_id
            JOIN users u ON u.id = g.user_id AND u.deleted_at IS NULL
            WHERE g.school_id = @school";
        return await DbHelper.QueryAsync(conn, sql, r => r.GetLong("student_id"), ct, ("@school", schoolId));
    }

    private static Guardian Map(System.Data.IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        UserId = r.GetLongOrNull("user_id"),
        FirstName = r.GetString("first_name"),
        LastName = r.GetString("last_name"),
        Relation = r.GetString("relation"),
        Email = r.GetStringOrNull("email"),
        Phone = r.GetString("phone"),
        Occupation = r.GetStringOrNull("occupation"),
        Address = r.GetStringOrNull("address"),
        Username = r.GetStringOrNull("username"),
    };
}
