using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class AttendanceRepository : IAttendanceRepository
{
    private readonly IDbConnectionFactory _factory;
    public AttendanceRepository(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>Roster for a section with any already-marked status for the date (default 'present').</summary>
    public async Task<IReadOnlyList<DailyAttendance>> GetSectionAsync(long schoolId, string className, string sectionName, DateTime date, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT s.id AS student_id, s.roll_no, CONCAT(s.first_name,' ',s.last_name) AS name,
                   COALESCE(a.status, 'present') AS status
            FROM students s
            LEFT JOIN daily_attendance a ON a.student_id = s.id AND a.attendance_date = @d
            WHERE s.school_id=@sid AND s.class_name=@cls AND s.section_name=@sec AND s.deleted_at IS NULL
            ORDER BY CAST(s.roll_no AS UNSIGNED), s.first_name LIMIT 80";
        return await DbHelper.QueryAsync(conn, sql, r => new DailyAttendance
        {
            StudentId = r.GetLong("student_id"),
            RollNo = r.GetStringOrNull("roll_no"),
            StudentName = r.GetString("name"),
            Status = r.GetString("status"),
        }, ct, ("@sid", schoolId), ("@cls", className), ("@sec", sectionName), ("@d", date.Date));
    }

    public async Task UpsertAsync(long schoolId, string className, string sectionName, DateTime date,
        IEnumerable<(long studentId, string status)> entries, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO daily_attendance (school_id, student_id, class_label, section_label, attendance_date, status)
            VALUES (@sid, @stu, @cls, @sec, @d, @status)
            ON DUPLICATE KEY UPDATE status = VALUES(status), class_label = VALUES(class_label), section_label = VALUES(section_label)";
        foreach (var (studentId, status) in entries)
            await DbHelper.ExecuteAsync(conn, sql, ct,
                ("@sid", schoolId), ("@stu", studentId), ("@cls", className), ("@sec", sectionName),
                ("@d", date.Date), ("@status", status));
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<(DateTime Date, int Present, int Total)>> GetDailyRatesAsync(
        long schoolId, int days, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Inner query takes the newest marked days; the outer one flips them back to chronological
        // order so the chart reads left-to-right.
        const string sql = @"
            SELECT * FROM (
              SELECT attendance_date,
                     SUM(status IN ('present','late')) AS present_count,
                     COUNT(*) AS total_count
              FROM daily_attendance
              WHERE school_id=@sid
              GROUP BY attendance_date
              ORDER BY attendance_date DESC
              LIMIT @take
            ) t ORDER BY attendance_date";
        return await DbHelper.QueryAsync(conn, sql,
            r => (r.GetDate("attendance_date"), r.GetInt("present_count"), r.GetInt("total_count")),
            ct, ("@sid", schoolId), ("@take", days));
    }

    public async Task<IReadOnlyList<DailyAttendance>> GetStudentRangeAsync(long schoolId, long studentId, DateTime from, DateTime to, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT attendance_date, status FROM daily_attendance
            WHERE school_id=@sid AND student_id=@stu AND attendance_date BETWEEN @from AND @to
            ORDER BY attendance_date";
        return await DbHelper.QueryAsync(conn, sql, r => new DailyAttendance
        {
            AttendanceDate = r.GetDate("attendance_date"),
            Status = r.GetString("status"),
        }, ct, ("@sid", schoolId), ("@stu", studentId), ("@from", from.Date), ("@to", to.Date));
    }
}
