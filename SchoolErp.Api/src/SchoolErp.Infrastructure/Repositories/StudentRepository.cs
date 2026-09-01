using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class StudentRepository : IStudentRepository
{
    private readonly IDbConnectionFactory _factory;
    public StudentRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = @"
        id, school_id, user_id, admission_no, roll_no, class_name, section_name,
        first_name, last_name, gender, dob, blood_group, email, phone,
        guardian_name, guardian_phone, current_address, city, state, pincode, state_id, city_id,
        previous_school, admission_date, fee_due, status, created_at";

    public async Task<IReadOnlyList<Student>> GetAllAsync(long schoolId, string? search, string? className, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM students WHERE school_id=@sid AND deleted_at IS NULL";
        var ps = new List<(string, object?)> { ("@sid", schoolId) };
        if (!string.IsNullOrWhiteSpace(search))
        {
            sql += " AND (first_name LIKE @q OR last_name LIKE @q OR admission_no LIKE @q OR guardian_name LIKE @q)";
            ps.Add(("@q", $"%{search}%"));
        }
        if (!string.IsNullOrWhiteSpace(className))
        {
            sql += " AND class_name = @cls";
            ps.Add(("@cls", className));
        }
        sql += " ORDER BY created_at DESC LIMIT 500";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<Student?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM students WHERE id=@id AND school_id=@sid AND deleted_at IS NULL";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task<long> CreateAsync(Student s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO students
              (school_id, admission_no, roll_no, class_name, section_name, first_name, last_name,
               gender, dob, blood_group, email, guardian_name, guardian_phone, current_address,
               city, state, pincode, state_id, city_id, previous_school, admission_date, fee_due, status, created_at, updated_at)
            VALUES
              (@sid, @adm, @roll, @cls, @sec, @fn, @ln, @gender, @dob, @blood, @email, @gname, @gphone,
               @addr, @city, @state, @pin, @stateId, @cityId, @prev, @admdate, @fee, @status, NOW(), NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", s.SchoolId), ("@adm", s.AdmissionNo), ("@roll", s.RollNo), ("@cls", s.ClassName),
            ("@sec", s.SectionName), ("@fn", s.FirstName), ("@ln", s.LastName), ("@gender", s.Gender),
            ("@dob", (object?)s.Dob), ("@blood", s.BloodGroup), ("@email", s.Email),
            ("@gname", s.GuardianName), ("@gphone", s.GuardianPhone), ("@addr", s.Address),
            ("@city", s.City), ("@state", s.State), ("@pin", s.Pincode),
            ("@stateId", (object?)s.StateId), ("@cityId", (object?)s.CityId), ("@prev", s.PreviousSchool),
            ("@admdate", (object?)s.AdmissionDate), ("@fee", s.FeeDue), ("@status", s.Status));
    }

    public async Task UpdateAsync(Student s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            UPDATE students SET
              roll_no=@roll, class_name=@cls, section_name=@sec, first_name=@fn, last_name=@ln,
              gender=@gender, dob=@dob, blood_group=@blood, email=@email, guardian_name=@gname,
              guardian_phone=@gphone, current_address=@addr, city=@city, state=@state, pincode=@pin,
              state_id=@stateId, city_id=@cityId,
              previous_school=@prev, updated_at=NOW()
            WHERE id=@id AND school_id=@sid;";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@roll", s.RollNo), ("@cls", s.ClassName), ("@sec", s.SectionName), ("@fn", s.FirstName),
            ("@ln", s.LastName), ("@gender", s.Gender), ("@dob", (object?)s.Dob), ("@blood", s.BloodGroup),
            ("@email", s.Email), ("@gname", s.GuardianName), ("@gphone", s.GuardianPhone),
            ("@addr", s.Address), ("@city", s.City), ("@state", s.State), ("@pin", s.Pincode),
            ("@stateId", (object?)s.StateId), ("@cityId", (object?)s.CityId),
            ("@prev", s.PreviousSchool), ("@id", s.Id), ("@sid", s.SchoolId));
    }

    public async Task SetStatusAsync(long schoolId, long id, string status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE students SET status=@st, updated_at=NOW() WHERE id=@id AND school_id=@sid", ct,
            ("@st", status), ("@id", id), ("@sid", schoolId));
    }

    public async Task<int> CountAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM students WHERE school_id=@sid AND deleted_at IS NULL AND status='active'", ct,
            ("@sid", schoolId));
    }

    public async Task<decimal> TotalFeesDueAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ScalarDecimalAsync(conn,
            "SELECT COALESCE(SUM(fee_due),0) FROM students WHERE school_id=@sid AND deleted_at IS NULL", ct,
            ("@sid", schoolId));
    }

    public async Task<IReadOnlyList<Student>> RecentAsync(long schoolId, int take, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {Cols} FROM students
                     WHERE school_id=@sid AND deleted_at IS NULL AND admission_date IS NOT NULL
                     ORDER BY admission_date DESC, id DESC LIMIT @take";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@sid", schoolId), ("@take", take));
    }

    public async Task<string> NextAdmissionNoAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var n = await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM students WHERE school_id=@sid", ct, ("@sid", schoolId));
        return $"ADM-2083-{(n + 1):D4}";
    }

    /// <summary>
    /// Highest purely numeric roll number already used in the class/section, plus one.
    /// Non-numeric roll numbers (e.g. "8A-04") are ignored so they cannot break the sequence.
    /// </summary>
    public async Task<string> NextRollNoAsync(long schoolId, string? className, string? sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var max = await DbHelper.ScalarLongAsync(conn, @"
            SELECT COALESCE(MAX(CAST(roll_no AS UNSIGNED)),0) FROM students
            WHERE school_id=@sid AND deleted_at IS NULL
              AND class_name <=> @cls AND section_name <=> @sec
              AND roll_no REGEXP '^[0-9]+$'", ct,
            ("@sid", schoolId), ("@cls", className), ("@sec", sectionName));
        return (max + 1).ToString();
    }

    public async Task SetUserIdAsync(long schoolId, long id, long userId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE students SET user_id=@uid, updated_at=NOW() WHERE id=@id AND school_id=@sid", ct,
            ("@uid", userId), ("@id", id), ("@sid", schoolId));
    }

    private static Student Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        UserId = r.GetLongOrNull("user_id"),
        AdmissionNo = r.GetString("admission_no"),
        RollNo = r.GetStringOrNull("roll_no"),
        ClassName = r.GetStringOrNull("class_name"),
        SectionName = r.GetStringOrNull("section_name"),
        FirstName = r.GetString("first_name"),
        LastName = r.GetString("last_name"),
        Gender = r.GetStringOrNull("gender"),
        Dob = r.GetDateOrNull("dob"),
        BloodGroup = r.GetStringOrNull("blood_group"),
        Email = r.GetStringOrNull("email"),
        Phone = r.GetStringOrNull("phone"),
        GuardianName = r.GetStringOrNull("guardian_name"),
        GuardianPhone = r.GetStringOrNull("guardian_phone"),
        Address = r.GetStringOrNull("current_address"),
        City = r.GetStringOrNull("city"),
        State = r.GetStringOrNull("state"),
        Pincode = r.GetStringOrNull("pincode"),
        StateId = r.GetLongOrNull("state_id"),
        CityId = r.GetLongOrNull("city_id"),
        PreviousSchool = r.GetStringOrNull("previous_school"),
        AdmissionDate = r.GetDateOrNull("admission_date"),
        FeeDue = r.GetDecimal("fee_due"),
        Status = r.GetString("status"),
        CreatedAt = r.GetDate("created_at"),
    };
}
