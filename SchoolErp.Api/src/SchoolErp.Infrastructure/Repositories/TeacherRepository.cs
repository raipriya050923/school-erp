using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class TeacherRepository : ITeacherRepository
{
    private readonly IDbConnectionFactory _factory;
    public TeacherRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = @"
        id, school_id, user_id, employee_code, staff_type, first_name, last_name, gender, dob,
        email, phone, address, city, state, pincode, state_id, city_id, qualification, specialization,
        joining_date, status, created_at";

    public async Task<IReadOnlyList<StaffMember>> GetAllAsync(long schoolId, string? search, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM staff WHERE school_id=@sid AND staff_type='teacher' AND deleted_at IS NULL";
        var ps = new List<(string, object?)> { ("@sid", schoolId) };
        if (!string.IsNullOrWhiteSpace(search))
        {
            sql += " AND (first_name LIKE @q OR last_name LIKE @q OR specialization LIKE @q)";
            ps.Add(("@q", $"%{search}%"));
        }
        sql += " ORDER BY created_at DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<StaffMember?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM staff WHERE id=@id AND school_id=@sid AND deleted_at IS NULL";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task<long> CreateAsync(StaffMember s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO staff
              (school_id, employee_code, staff_type, first_name, last_name, gender, dob, email, phone,
               address, city, state, pincode, state_id, city_id, qualification, specialization,
               joining_date, status, created_at, updated_at)
            VALUES
              (@sid, @code, 'teacher', @fn, @ln, @gender, @dob, @email, @phone, @addr, @city, @state,
               @pin, @stateId, @cityId, @qual, @spec, @join, @status, NOW(), NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", s.SchoolId), ("@code", s.EmployeeCode), ("@fn", s.FirstName), ("@ln", s.LastName),
            ("@gender", s.Gender), ("@dob", (object?)s.Dob), ("@email", s.Email), ("@phone", s.Phone),
            ("@addr", s.Address), ("@city", s.City), ("@state", s.State), ("@pin", s.Pincode),
            ("@stateId", (object?)s.StateId), ("@cityId", (object?)s.CityId),
            ("@qual", s.Qualification), ("@spec", s.Specialization),
            ("@join", (object?)s.JoiningDate), ("@status", s.Status));
    }

    public async Task UpdateAsync(StaffMember s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            UPDATE staff SET
              first_name=@fn, last_name=@ln, gender=@gender, dob=@dob, email=@email, phone=@phone,
              address=@addr, city=@city, state=@state, pincode=@pin,
              state_id=@stateId, city_id=@cityId, qualification=@qual,
              specialization=@spec, updated_at=NOW()
            WHERE id=@id AND school_id=@sid;";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@fn", s.FirstName), ("@ln", s.LastName), ("@gender", s.Gender), ("@dob", (object?)s.Dob),
            ("@email", s.Email), ("@phone", s.Phone), ("@addr", s.Address), ("@city", s.City),
            ("@state", s.State), ("@pin", s.Pincode),
            ("@stateId", (object?)s.StateId), ("@cityId", (object?)s.CityId), ("@qual", s.Qualification),
            ("@spec", s.Specialization), ("@id", s.Id), ("@sid", s.SchoolId));
    }

    public async Task SetStatusAsync(long schoolId, long id, string status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE staff SET status=@st, updated_at=NOW() WHERE id=@id AND school_id=@sid", ct,
            ("@st", status), ("@id", id), ("@sid", schoolId));
    }

    public async Task<int> CountAsync(long schoolId, string? status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM staff WHERE school_id=@sid AND staff_type='teacher' AND deleted_at IS NULL";
        var ps = new List<(string, object?)> { ("@sid", schoolId) };
        if (!string.IsNullOrWhiteSpace(status)) { sql += " AND status=@st"; ps.Add(("@st", status)); }
        return (int)await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray());
    }

    public async Task<string> NextEmployeeCodeAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var n = await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM staff WHERE school_id=@sid", ct, ("@sid", schoolId));
        return $"EMP-{(n + 31):D3}";
    }

    public async Task SetUserIdAsync(long schoolId, long id, long userId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE staff SET user_id=@uid, updated_at=NOW() WHERE id=@id AND school_id=@sid", ct,
            ("@uid", userId), ("@id", id), ("@sid", schoolId));
    }

    public async Task<IReadOnlyDictionary<long, string>> GetClassTeacherSectionsAsync(
        long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT sec.class_teacher_id AS staff_id, CONCAT(c.name, ' — ', sec.name) AS label
            FROM sections sec
            JOIN classes c ON c.id = sec.class_id
            WHERE sec.school_id=@sid AND sec.class_teacher_id IS NOT NULL
            ORDER BY c.numeric_level, c.name, sec.name";
        var rows = await DbHelper.QueryAsync(conn, sql,
            r => (StaffId: r.GetLong("staff_id"), Label: r.GetString("label")), ct, ("@sid", schoolId));

        // A teacher should own one section only, but older data may hold more; keep the first so
        // the list still renders instead of throwing on a duplicate key.
        var map = new Dictionary<long, string>();
        foreach (var (staffId, label) in rows)
            if (!map.ContainsKey(staffId)) map[staffId] = label;
        return map;
    }

    public async Task<IReadOnlyList<string>> GetSubjectsAsync(long schoolId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn, @"
            SELECT sub.name
            FROM staff_subjects ss
            JOIN subjects sub ON sub.id = ss.subject_id
            WHERE ss.school_id=@sid AND ss.staff_id=@id
            ORDER BY sub.name",
            r => r.GetString("name"), ct, ("@sid", schoolId), ("@id", staffId));
    }

    public async Task<IReadOnlyDictionary<long, IReadOnlyList<string>>> GetSubjectsForAllAsync(
        long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // One query for the whole list rather than one per teacher: the teachers screen would
        // otherwise issue a round trip per row.
        var rows = await DbHelper.QueryAsync(conn, @"
            SELECT ss.staff_id, sub.name
            FROM staff_subjects ss
            JOIN subjects sub ON sub.id = ss.subject_id
            WHERE ss.school_id=@sid
            ORDER BY ss.staff_id, sub.name",
            r => (StaffId: r.GetLong("staff_id"), Name: r.GetString("name")), ct, ("@sid", schoolId));

        return rows.GroupBy(x => x.StaffId)
            .ToDictionary(g => g.Key, g => (IReadOnlyList<string>)g.Select(x => x.Name).ToList());
    }

    public async Task ReplaceSubjectsAsync(long schoolId, long staffId,
        IEnumerable<string> subjectNames, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "DELETE FROM staff_subjects WHERE school_id=@sid AND staff_id=@id", ct,
            ("@sid", schoolId), ("@id", staffId));

        var clean = subjectNames
            .Select(n => n?.Trim() ?? "")
            .Where(n => n.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(20)
            .ToList();

        foreach (var name in clean)
            // Resolved through subjects rather than trusting an id from the client: a name that
            // matches nothing in this school simply writes no row.
            await DbHelper.ExecuteAsync(conn, @"
                INSERT IGNORE INTO staff_subjects (school_id, staff_id, subject_id)
                SELECT @sid, @id, sub.id FROM subjects sub
                WHERE sub.school_id=@sid AND sub.name=@name", ct,
                ("@sid", schoolId), ("@id", staffId), ("@name", name));
    }

    public async Task<IReadOnlyList<StaffQualification>> GetQualificationsAsync(long schoolId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn, @"
            SELECT id, qualification, institution, completion_year FROM staff_qualifications
            WHERE school_id=@sid AND staff_id=@id
            ORDER BY sort_order, id",
            r => new StaffQualification
            {
                Id = r.GetLong("id"),
                Name = r.GetString("qualification"),
                Institution = r.GetStringOrNull("institution"),
                CompletionYear = r.GetIntOrNull("completion_year"),
            }, ct, ("@sid", schoolId), ("@id", staffId));
    }

    /// <summary>
    /// Replace rather than diff: the form always posts the complete list, and the rows carry no
    /// state worth preserving. Blank and duplicate entries are dropped here so the UI does not
    /// have to be trusted for it.
    /// </summary>
    public async Task ReplaceQualificationsAsync(long schoolId, long staffId,
        IEnumerable<StaffQualification> qualifications, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "DELETE FROM staff_qualifications WHERE school_id=@sid AND staff_id=@id", ct,
            ("@sid", schoolId), ("@id", staffId));

        // De-duplicated on name plus institution, not name alone: the same degree from two
        // universities is two qualifications, and an admin recording both is not a mistake.
        var clean = qualifications
            .Where(q => !string.IsNullOrWhiteSpace(q.Name))
            .Select(q => new StaffQualification
            {
                Name = Clip(q.Name.Trim(), 150),
                Institution = string.IsNullOrWhiteSpace(q.Institution) ? null : Clip(q.Institution.Trim(), 150),
                CompletionYear = q.CompletionYear,
            })
            .DistinctBy(q => (q.Name.ToLowerInvariant(), q.Institution?.ToLowerInvariant()))
            .Take(20)
            .ToList();

        for (var i = 0; i < clean.Count; i++)
            await DbHelper.ExecuteAsync(conn, @"
                INSERT INTO staff_qualifications (school_id, staff_id, qualification, institution, completion_year, sort_order)
                VALUES (@sid, @id, @q, @inst, @year, @order)", ct,
                ("@sid", schoolId), ("@id", staffId),
                ("@q", clean[i].Name), ("@inst", clean[i].Institution),
                ("@year", (object?)clean[i].CompletionYear), ("@order", i));
    }

    private static string Clip(string s, int max) => s.Length > max ? s[..max] : s;

    private static StaffMember Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        UserId = r.GetLongOrNull("user_id"),
        EmployeeCode = r.GetString("employee_code"),
        StaffType = r.GetString("staff_type"),
        FirstName = r.GetString("first_name"),
        LastName = r.GetString("last_name"),
        Gender = r.GetStringOrNull("gender"),
        Dob = r.GetDateOrNull("dob"),
        Email = r.GetStringOrNull("email"),
        Phone = r.GetStringOrNull("phone"),
        Address = r.GetStringOrNull("address"),
        City = r.GetStringOrNull("city"),
        State = r.GetStringOrNull("state"),
        Pincode = r.GetStringOrNull("pincode"),
        StateId = r.GetLongOrNull("state_id"),
        CityId = r.GetLongOrNull("city_id"),
        Qualification = r.GetStringOrNull("qualification"),
        Specialization = r.GetStringOrNull("specialization"),
        JoiningDate = r.GetDateOrNull("joining_date"),
        Status = r.GetString("status"),
        CreatedAt = r.GetDate("created_at"),
    };
}
