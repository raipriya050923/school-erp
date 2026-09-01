using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class LeaveRepository : ILeaveRepository
{
    private readonly IDbConnectionFactory _factory;
    public LeaveRepository(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>The set every school starts with; mirrors migration 009.</summary>
    private static readonly (string Name, bool Paid, int? MaxDays)[] DefaultTypes =
    {
        ("Sick Leave", true, 12),
        ("Casual Leave", true, 12),
        ("Annual Leave", true, 15),
        ("Unpaid Leave", false, null),
    };

    public async Task<IReadOnlyList<LeaveType>> GetTypesAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            @"SELECT id, school_id, name, applicable_to, max_days_per_year, is_paid
              FROM leave_types WHERE school_id=@sid AND applicable_to IN ('staff','both') ORDER BY name",
            r => new LeaveType
            {
                Id = r.GetLong("id"),
                SchoolId = r.GetLong("school_id"),
                Name = r.GetString("name"),
                ApplicableTo = r.GetString("applicable_to"),
                MaxDaysPerYear = r.GetIntOrNull("max_days_per_year"),
                IsPaid = r.GetBool("is_paid"),
            }, ct, ("@sid", schoolId));
    }

    public async Task SeedDefaultTypesAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        foreach (var (name, paid, maxDays) in DefaultTypes)
        {
            // uq_lt (school_id, name) makes this idempotent.
            await DbHelper.ExecuteAsync(conn,
                @"INSERT IGNORE INTO leave_types (school_id, name, applicable_to, max_days_per_year, is_paid)
                  VALUES (@sid, @name, 'staff', @max, @paid)", ct,
                ("@sid", schoolId), ("@name", name), ("@max", (object?)maxDays), ("@paid", paid));
        }
    }

    public async Task<bool> TypeNameExistsAsync(long schoolId, string name, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM leave_types WHERE school_id=@sid AND name=@name", ct,
            ("@sid", schoolId), ("@name", name)) > 0;
    }

    public async Task<long> CreateTypeAsync(LeaveType t, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn,
            @"INSERT INTO leave_types (school_id, name, applicable_to, max_days_per_year, is_paid)
              VALUES (@sid, @name, 'staff', @max, @paid)", ct,
            ("@sid", t.SchoolId), ("@name", t.Name),
            ("@max", (object?)t.MaxDaysPerYear), ("@paid", t.IsPaid));
    }

    private const string SelectJoined = @"
        SELECT la.id, la.school_id, la.leave_type_id, la.applicant_user_id, la.from_date, la.to_date,
               la.days, la.reason, la.status, la.reviewed_by, la.reviewed_at, la.review_remarks, la.created_at,
               lt.name AS leave_type_name,
               applicant.full_name AS applicant_name,
               reviewer.full_name  AS reviewed_by_name
        FROM leave_applications la
        JOIN leave_types lt        ON lt.id = la.leave_type_id
        JOIN users applicant       ON applicant.id = la.applicant_user_id
        LEFT JOIN users reviewer   ON reviewer.id = la.reviewed_by";

    public async Task<IReadOnlyList<LeaveApplication>> GetAllAsync(long schoolId, string? status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"{SelectJoined} WHERE la.school_id=@sid";
        var ps = new List<(string, object?)> { ("@sid", schoolId) };
        if (!string.IsNullOrWhiteSpace(status)) { sql += " AND la.status=@st"; ps.Add(("@st", status)); }
        sql += " ORDER BY la.created_at DESC, la.id DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<IReadOnlyList<LeaveApplication>> GetForApplicantAsync(long schoolId, long userId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"{SelectJoined} WHERE la.school_id=@sid AND la.applicant_user_id=@uid ORDER BY la.created_at DESC, la.id DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@sid", schoolId), ("@uid", userId));
    }

    public async Task<LeaveApplication?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $"{SelectJoined} WHERE la.id=@id AND la.school_id=@sid", Map, ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task<long> CreateAsync(LeaveApplication a, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn, @"
            INSERT INTO leave_applications
              (school_id, leave_type_id, applicant_user_id, from_date, to_date, days, reason, status, created_at)
            VALUES (@sid, @type, @uid, @from, @to, @days, @reason, 'pending', NOW())", ct,
            ("@sid", a.SchoolId), ("@type", a.LeaveTypeId), ("@uid", a.ApplicantUserId),
            ("@from", a.FromDate.Date), ("@to", a.ToDate.Date), ("@days", a.Days), ("@reason", a.Reason));
    }

    public async Task ReviewAsync(long schoolId, long id, string status, long reviewerUserId, string? remarks, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn, @"
            UPDATE leave_applications
            SET status=@st, reviewed_by=@by, reviewed_at=NOW(), review_remarks=@rem
            WHERE id=@id AND school_id=@sid", ct,
            ("@st", status), ("@by", reviewerUserId), ("@rem", remarks), ("@id", id), ("@sid", schoolId));
    }

    private static LeaveApplication Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        LeaveTypeId = r.GetLong("leave_type_id"),
        ApplicantUserId = r.GetLong("applicant_user_id"),
        FromDate = r.GetDate("from_date"),
        ToDate = r.GetDate("to_date"),
        Days = r.GetDecimal("days"),
        Reason = r.GetString("reason"),
        Status = r.GetString("status"),
        ReviewedBy = r.GetLongOrNull("reviewed_by"),
        ReviewedAt = r.GetDateOrNull("reviewed_at"),
        ReviewRemarks = r.GetStringOrNull("review_remarks"),
        CreatedAt = r.GetDate("created_at"),
        LeaveTypeName = r.GetStringOrNull("leave_type_name"),
        ApplicantName = r.GetStringOrNull("applicant_name"),
        ReviewedByName = r.GetStringOrNull("reviewed_by_name"),
    };
}
