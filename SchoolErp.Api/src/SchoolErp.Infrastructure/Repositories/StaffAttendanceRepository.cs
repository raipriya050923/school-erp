using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class StaffAttendanceRepository : IStaffAttendanceRepository
{
    private readonly IDbConnectionFactory _factory;
    public StaffAttendanceRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<StaffAttendance>> GetForDateAsync(long schoolId, DateTime date, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Driven from staff so everyone appears whether or not they have been marked. The COALESCE
        // chain is the precedence: what was saved, else an approved leave, else present.
        const string sql = @"
            SELECT st.id AS staff_id,
                   CONCAT(st.first_name, ' ', st.last_name) AS staff_name,
                   st.employee_code,
                   COALESCE(sa.status, IF(la.id IS NULL, 'present', 'on_leave')) AS status,
                   sa.remarks
            FROM staff st
            LEFT JOIN staff_attendance sa
                   ON sa.staff_id = st.id AND sa.attendance_date = @d
            LEFT JOIN leave_applications la
                   ON la.applicant_user_id = st.user_id
                  AND la.status = 'approved'
                  AND @d BETWEEN la.from_date AND la.to_date
            WHERE st.school_id = @sid AND st.deleted_at IS NULL AND st.status <> 'resigned'
            ORDER BY st.first_name, st.last_name";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@sid", schoolId), ("@d", date.Date));
    }

    public async Task UpsertAsync(long schoolId, DateTime date, long markedByUserId,
        IEnumerable<(long StaffId, string Status, string? Remarks)> entries, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        foreach (var (staffId, status, remarks) in entries)
        {
            // uq_sta (staff_id, attendance_date) makes re-marking a day an update, not a duplicate.
            await DbHelper.ExecuteAsync(conn, @"
                INSERT INTO staff_attendance (school_id, staff_id, attendance_date, status, remarks, marked_by)
                VALUES (@sid, @staff, @d, @st, @rem, @by)
                ON DUPLICATE KEY UPDATE status=VALUES(status), remarks=VALUES(remarks), marked_by=VALUES(marked_by)", ct,
                ("@sid", schoolId), ("@staff", staffId), ("@d", date.Date),
                ("@st", status), ("@rem", remarks), ("@by", markedByUserId));
        }
    }

    public async Task<IReadOnlyList<(string Status, int Count)>> SummaryAsync(
        long schoolId, DateTime from, DateTime to, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT status, COUNT(*) AS n
            FROM staff_attendance
            WHERE school_id=@sid AND attendance_date BETWEEN @from AND @to
            GROUP BY status";
        return await DbHelper.QueryAsync(conn, sql,
            r => (r.GetString("status"), r.GetInt("n")), ct,
            ("@sid", schoolId), ("@from", from.Date), ("@to", to.Date));
    }

    private static StaffAttendance Map(IDataRecord r) => new()
    {
        StaffId = r.GetLong("staff_id"),
        StaffName = r.GetStringOrNull("staff_name"),
        EmployeeCode = r.GetStringOrNull("employee_code"),
        Status = r.GetString("status"),
        Remarks = r.GetStringOrNull("remarks"),
    };
}
