using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class ClassRepository : IClassRepository
{
    private readonly IDbConnectionFactory _factory;
    public ClassRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<SchoolClass>> GetAllWithSectionsAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var classes = await DbHelper.QueryAsync(conn,
            "SELECT id, school_id, name, numeric_level, is_active FROM classes WHERE school_id=@sid ORDER BY numeric_level, name",
            MapClass, ct, ("@sid", schoolId));

        // sections + per-section student counts (by class_name/section_name denormalised columns)
        var sections = await DbHelper.QueryAsync(conn, @"
            SELECT sec.id, sec.school_id, sec.class_id, sec.name,
                   (SELECT full_name FROM users u WHERE u.id = st.user_id) AS teacher_name,
                   (SELECT COUNT(*) FROM students stu
                     WHERE stu.school_id = sec.school_id AND stu.class_name = c.name
                       AND stu.section_name = sec.name AND stu.deleted_at IS NULL) AS student_count
            FROM sections sec
            JOIN classes c ON c.id = sec.class_id
            LEFT JOIN staff st ON st.id = sec.class_teacher_id
            WHERE sec.school_id=@sid
            ORDER BY sec.name", MapSection, ct, ("@sid", schoolId));

        foreach (var c in classes)
            c.Sections = sections.Where(s => s.ClassId == c.Id).ToList();
        return classes;
    }

    public async Task<SchoolClass?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            "SELECT id, school_id, name, numeric_level, is_active FROM classes WHERE id=@id AND school_id=@sid",
            MapClass, ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task<bool> ExistsByNameAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM classes WHERE school_id=@sid AND name=@name";
        var ps = new List<(string, object?)> { ("@sid", schoolId), ("@name", name) };
        if (excludeId.HasValue) { sql += " AND id<>@id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    public async Task<long> CreateClassAsync(long schoolId, string name, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn,
            "INSERT INTO classes (school_id, name, is_active) VALUES (@sid, @name, 1)", ct,
            ("@sid", schoolId), ("@name", name));
    }

    public async Task RenameClassAsync(long schoolId, long id, string name, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn, "UPDATE classes SET name=@name WHERE id=@id AND school_id=@sid", ct,
            ("@name", name), ("@id", id), ("@sid", schoolId));
    }

    public async Task DeleteClassAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn, "DELETE FROM sections WHERE class_id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
        await DbHelper.ExecuteAsync(conn, "DELETE FROM classes WHERE id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task<int> CountAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM classes WHERE school_id=@sid", ct, ("@sid", schoolId));
    }

    public async Task<bool> SectionExistsAsync(long classId, string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM sections WHERE class_id=@cid AND name=@name";
        var ps = new List<(string, object?)> { ("@cid", classId), ("@name", name) };
        if (excludeId.HasValue) { sql += " AND id<>@id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    public async Task<long> AddSectionAsync(long schoolId, long classId, string name, string? teacher, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var teacherId = await ResolveTeacherIdAsync(conn, schoolId, teacher, ct);
        return await DbHelper.InsertAsync(conn,
            "INSERT INTO sections (school_id, class_id, name, class_teacher_id, is_active) VALUES (@sid, @cid, @name, @tid, 1)", ct,
            ("@sid", schoolId), ("@cid", classId), ("@name", name), ("@tid", (object?)teacherId));
    }

    public async Task UpdateSectionAsync(long schoolId, long id, string name, string? teacher, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var teacherId = await ResolveTeacherIdAsync(conn, schoolId, teacher, ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE sections SET name=@name, class_teacher_id=@tid WHERE id=@id AND school_id=@sid", ct,
            ("@name", name), ("@tid", (object?)teacherId), ("@id", id), ("@sid", schoolId));
    }

    public async Task DeleteSectionAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn, "DELETE FROM sections WHERE id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
    }

    private static async Task<long?> ResolveTeacherIdAsync(IDbConnection conn, long schoolId, string? teacherName, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(teacherName)) return null;
        var id = await DbHelper.ScalarLongAsync(conn,
            "SELECT id FROM staff WHERE school_id=@sid AND CONCAT(first_name,' ',last_name)=@n LIMIT 1", ct,
            ("@sid", schoolId), ("@n", teacherName));
        return id == 0 ? null : id;
    }

    private static SchoolClass MapClass(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        Name = r.GetString("name"),
        NumericLevel = (short?)r.GetIntOrNull("numeric_level"),
        IsActive = r.GetBool("is_active"),
    };

    private static ClassSection MapSection(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        ClassId = r.GetLong("class_id"),
        Name = r.GetString("name"),
        Teacher = r.GetStringOrNull("teacher_name"),
        StudentCount = r.GetInt("student_count"),
    };
}
