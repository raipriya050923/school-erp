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
        email, phone, address, city, state, pincode, qualification, specialization,
        classes_taught, joining_date, status, created_at";

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
               address, city, state, pincode, qualification, specialization, classes_taught,
               joining_date, status, created_at, updated_at)
            VALUES
              (@sid, @code, 'teacher', @fn, @ln, @gender, @dob, @email, @phone, @addr, @city, @state,
               @pin, @qual, @spec, @classes, @join, @status, NOW(), NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", s.SchoolId), ("@code", s.EmployeeCode), ("@fn", s.FirstName), ("@ln", s.LastName),
            ("@gender", s.Gender), ("@dob", (object?)s.Dob), ("@email", s.Email), ("@phone", s.Phone),
            ("@addr", s.Address), ("@city", s.City), ("@state", s.State), ("@pin", s.Pincode),
            ("@qual", s.Qualification), ("@spec", s.Specialization), ("@classes", s.ClassesTaught),
            ("@join", (object?)s.JoiningDate), ("@status", s.Status));
    }

    public async Task UpdateAsync(StaffMember s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            UPDATE staff SET
              first_name=@fn, last_name=@ln, gender=@gender, dob=@dob, email=@email, phone=@phone,
              address=@addr, city=@city, state=@state, pincode=@pin, qualification=@qual,
              specialization=@spec, classes_taught=@classes, updated_at=NOW()
            WHERE id=@id AND school_id=@sid;";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@fn", s.FirstName), ("@ln", s.LastName), ("@gender", s.Gender), ("@dob", (object?)s.Dob),
            ("@email", s.Email), ("@phone", s.Phone), ("@addr", s.Address), ("@city", s.City),
            ("@state", s.State), ("@pin", s.Pincode), ("@qual", s.Qualification),
            ("@spec", s.Specialization), ("@classes", s.ClassesTaught), ("@id", s.Id), ("@sid", s.SchoolId));
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
        Qualification = r.GetStringOrNull("qualification"),
        Specialization = r.GetStringOrNull("specialization"),
        ClassesTaught = r.GetStringOrNull("classes_taught"),
        JoiningDate = r.GetDateOrNull("joining_date"),
        Status = r.GetString("status"),
        CreatedAt = r.GetDate("created_at"),
    };
}
