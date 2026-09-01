using System.Data;
using SchoolErp.Application.Common;
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
        // The name comes from the staff row, not from users: a teacher added through the admin
        // UI has no login account, so joining through staff.user_id returned NULL and the
        // assignment looked like it had never saved.
        var sections = await DbHelper.QueryAsync(conn, @"
            SELECT sec.id, sec.school_id, sec.class_id, sec.name,
                   CONCAT(st.first_name, ' ', st.last_name) AS teacher_name,
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

    public async Task<ClassUsage> GetClassUsageAsync(long schoolId, long classId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Students are matched on the denormalised class_name, which is how the students table
        // actually records them — there is no students.class_id to join on.
        const string sql = @"
            SELECT
              (SELECT COUNT(*) FROM students s JOIN classes c ON c.id=@cid
                WHERE s.school_id=@sid AND s.class_name = c.name AND s.deleted_at IS NULL) AS students,
              (SELECT COUNT(*) FROM student_enrollments WHERE class_id=@cid) AS enrollments,
              (SELECT COUNT(*) FROM fee_structures    WHERE class_id=@cid) AS fee_structures,
              (SELECT COUNT(*) FROM exam_schedules    WHERE class_id=@cid) AS exam_schedules";
        return await DbHelper.QuerySingleAsync(conn, sql, r => new ClassUsage(
            r.GetInt("students"), r.GetInt("enrollments"),
            r.GetInt("fee_structures"), r.GetInt("exam_schedules")), ct,
            ("@sid", schoolId), ("@cid", classId)) ?? new ClassUsage(0, 0, 0, 0);
    }

    /// <summary>
    /// Removes the class together with the configuration hanging off it — subject picks, teacher
    /// assignments, timetable slots and sections. Those are settings the school re-enters, and
    /// their foreign keys would otherwise block the delete outright. Anything representing
    /// history is guarded by <see cref="GetClassUsageAsync"/> before this is called.
    /// </summary>
    public async Task DeleteClassAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var name = await DbHelper.QuerySingleAsync(conn,
            "SELECT name FROM classes WHERE id=@id AND school_id=@sid",
            r => new { Name = r.GetString("name") }, ct, ("@id", id), ("@sid", schoolId));

        await DbHelper.ExecuteAsync(conn, "DELETE FROM teacher_assignments WHERE class_id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
        await DbHelper.ExecuteAsync(conn, "DELETE FROM class_subjects WHERE class_id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
        // timetable_slot stores the class by label, not by id, so it is cleared by name.
        if (name is not null)
            await DbHelper.ExecuteAsync(conn, "DELETE FROM timetable_slot WHERE school_id=@sid AND class_label=@name", ct, ("@sid", schoolId), ("@name", name.Name));
        await DbHelper.ExecuteAsync(conn, "DELETE FROM sections WHERE class_id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
        await DbHelper.ExecuteAsync(conn, "DELETE FROM classes WHERE id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task<ClassUsage> GetSectionUsageAsync(long schoolId, long sectionId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT
              (SELECT COUNT(*) FROM students s
                 JOIN sections sec ON sec.id=@secid
                 JOIN classes c    ON c.id = sec.class_id
                WHERE s.school_id=@sid AND s.class_name = c.name AND s.section_name = sec.name
                  AND s.deleted_at IS NULL) AS students,
              (SELECT COUNT(*) FROM student_enrollments WHERE section_id=@secid) AS enrollments,
              0 AS fee_structures, 0 AS exam_schedules";
        return await DbHelper.QuerySingleAsync(conn, sql, r => new ClassUsage(
            r.GetInt("students"), r.GetInt("enrollments"), 0, 0), ct,
            ("@sid", schoolId), ("@secid", sectionId)) ?? new ClassUsage(0, 0, 0, 0);
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
        await EnsureNotAlreadyClassTeacherAsync(conn, schoolId, teacherId, null, teacher, ct);
        return await DbHelper.InsertAsync(conn,
            "INSERT INTO sections (school_id, class_id, name, class_teacher_id, is_active) VALUES (@sid, @cid, @name, @tid, 1)", ct,
            ("@sid", schoolId), ("@cid", classId), ("@name", name), ("@tid", (object?)teacherId));
    }

    public async Task UpdateSectionAsync(long schoolId, long id, string name, string? teacher, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var teacherId = await ResolveTeacherIdAsync(conn, schoolId, teacher, ct);
        await EnsureNotAlreadyClassTeacherAsync(conn, schoolId, teacherId, id, teacher, ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE sections SET name=@name, class_teacher_id=@tid WHERE id=@id AND school_id=@sid", ct,
            ("@name", name), ("@tid", (object?)teacherId), ("@id", id), ("@sid", schoolId));
    }

    /// <summary>Clears the same configuration as a class delete, scoped to the one section.</summary>
    public async Task DeleteSectionAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var labels = await DbHelper.QuerySingleAsync(conn, @"
            SELECT c.name AS class_name, sec.name AS section_name
            FROM sections sec JOIN classes c ON c.id = sec.class_id
            WHERE sec.id=@id AND sec.school_id=@sid",
            r => new { ClassName = r.GetString("class_name"), SectionName = r.GetString("section_name") },
            ct, ("@id", id), ("@sid", schoolId));

        await DbHelper.ExecuteAsync(conn, "DELETE FROM teacher_assignments WHERE section_id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
        if (labels is not null)
            await DbHelper.ExecuteAsync(conn, @"
                DELETE FROM timetable_slot
                WHERE school_id=@sid AND class_label=@cls AND section_label=@sec", ct,
                ("@sid", schoolId), ("@cls", labels.ClassName), ("@sec", labels.SectionName));
        await DbHelper.ExecuteAsync(conn, "DELETE FROM sections WHERE id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
    }

    /// <summary>
    /// Maps the teacher name the UI sends onto a staff id. Blank means "unassigned"; anything
    /// else that fails to match is reported rather than silently stored as NULL, which used to
    /// make a mistyped or stale name look like a successful save.
    /// </summary>
    private static async Task<long?> ResolveTeacherIdAsync(IDbConnection conn, long schoolId, string? teacherName, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(teacherName)) return null;
        var name = teacherName.Trim();
        var id = await DbHelper.ScalarLongAsync(conn,
            @"SELECT id FROM staff
              WHERE school_id=@sid AND deleted_at IS NULL
                AND TRIM(CONCAT(first_name,' ',last_name)) = @n
              ORDER BY id LIMIT 1", ct,
            ("@sid", schoolId), ("@n", name));
        if (id == 0)
            throw new ValidationException($"No teacher named “{name}” exists at this school.");
        return id;
    }

    /// <summary>
    /// A teacher can be the class teacher of one section only — the role is pastoral ownership of
    /// a single group, not a subject they can teach in several. Subject teaching across many
    /// sections goes through `teacher_assignments` instead. The message names the section that
    /// already holds them so the admin knows where to look.
    /// </summary>
    private static async Task EnsureNotAlreadyClassTeacherAsync(IDbConnection conn, long schoolId,
        long? teacherId, long? excludeSectionId, string? teacherName, CancellationToken ct)
    {
        if (teacherId is not { } staffId) return;   // clearing the assignment is always fine

        var sql = @"
            SELECT CONCAT(c.name, ' — ', sec.name) AS label
            FROM sections sec
            JOIN classes c ON c.id = sec.class_id
            WHERE sec.school_id=@sid AND sec.class_teacher_id=@tid";
        var ps = new List<(string, object?)> { ("@sid", schoolId), ("@tid", staffId) };
        if (excludeSectionId is { } exclude) { sql += " AND sec.id <> @exclude"; ps.Add(("@exclude", exclude)); }
        sql += " LIMIT 1";

        var existing = await DbHelper.QuerySingleAsync(conn, sql,
            r => new { Label = r.GetString("label") }, ct, ps.ToArray());
        if (existing is null) return;

        throw new ValidationException(
            $"{teacherName?.Trim()} is already the class teacher of {existing.Label}. " +
            "A teacher can be class teacher of one section only — free that section first, " +
            "or add them as a subject teacher under Subjects & Teachers.");
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
