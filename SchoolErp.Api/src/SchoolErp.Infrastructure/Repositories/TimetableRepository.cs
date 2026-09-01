using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class TimetableRepository : ITimetableRepository
{
    private readonly IDbConnectionFactory _factory;
    public TimetableRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string SlotColumns = @"
        ts.id, ts.school_id, ts.class_label, ts.section_label, ts.day_of_week, ts.period_no,
        ts.time_label, ts.subject, ts.room, ts.teacher_staff_id,
        CONCAT(st.first_name, ' ', st.last_name) AS teacher_name";

    private const string SlotFrom = @"
        FROM timetable_slot ts
        LEFT JOIN staff st ON st.id = ts.teacher_staff_id";

    public async Task<IReadOnlyList<TimetableSlot>> GetByTeacherAsync(long schoolId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {SlotColumns} {SlotFrom}
                     WHERE ts.school_id=@sid AND ts.teacher_staff_id=@tid
                     ORDER BY ts.day_of_week, ts.period_no";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@sid", schoolId), ("@tid", staffId));
    }

    public async Task<IReadOnlyList<TimetablePeriod>> GetPeriodsAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT id, school_id, name, start_time, end_time, is_break, sort_order
            FROM timetable_periods WHERE school_id=@sid ORDER BY sort_order, start_time";
        return await DbHelper.QueryAsync(conn, sql, r => new TimetablePeriod
        {
            Id = r.GetLong("id"),
            SchoolId = r.GetLong("school_id"),
            Name = r.GetString("name"),
            StartTime = (TimeSpan)r.GetValue(r.GetOrdinal("start_time")),
            EndTime = (TimeSpan)r.GetValue(r.GetOrdinal("end_time")),
            IsBreak = r.GetBool("is_break"),
            SortOrder = r.GetInt("sort_order"),
        }, ct, ("@sid", schoolId));
    }

    /// <summary>Mirrors migration 011 for a school created after it ran.</summary>
    public async Task SeedDefaultPeriodsAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO timetable_periods (school_id, name, start_time, end_time, is_break, sort_order)
            SELECT @sid, p.name, p.start_time, p.end_time, p.is_break, p.sort_order
            FROM (
                SELECT 'P1' AS name, '10:00:00' AS start_time, '10:45:00' AS end_time, 0 AS is_break, 1 AS sort_order
                UNION ALL SELECT 'P2', '10:45:00', '11:30:00', 0, 2
                UNION ALL SELECT 'P3', '11:30:00', '12:15:00', 0, 3
                UNION ALL SELECT 'Break', '12:15:00', '12:45:00', 1, 4
                UNION ALL SELECT 'P4', '12:45:00', '13:30:00', 0, 5
                UNION ALL SELECT 'P5', '13:30:00', '14:15:00', 0, 6
                UNION ALL SELECT 'P6', '14:15:00', '15:00:00', 0, 7
            ) p
            WHERE NOT EXISTS (SELECT 1 FROM timetable_periods tp WHERE tp.school_id = @sid)";
        await DbHelper.ExecuteAsync(conn, sql, ct, ("@sid", schoolId));
    }

    public async Task<IReadOnlyList<TimetableSlot>> GetForSectionAsync(long schoolId, string className,
        string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {SlotColumns} {SlotFrom}
                     WHERE ts.school_id=@sid AND ts.class_label=@cls AND ts.section_label=@sec
                     ORDER BY ts.day_of_week, ts.period_no";
        return await DbHelper.QueryAsync(conn, sql, Map, ct,
            ("@sid", schoolId), ("@cls", className), ("@sec", sectionName));
    }

    /// <summary>
    /// Keyed on the cell (uq_tt_cell), so re-saving a period replaces what was there rather than
    /// stacking a second subject on it.
    /// </summary>
    public async Task UpsertSlotAsync(TimetableSlot s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO timetable_slot
              (school_id, class_label, section_label, day_of_week, period_no, time_label, subject, room, teacher_staff_id)
            VALUES (@sid, @cls, @sec, @day, @period, @time, @subject, @room, @staff)
            ON DUPLICATE KEY UPDATE
              time_label = VALUES(time_label), subject = VALUES(subject),
              room = VALUES(room), teacher_staff_id = VALUES(teacher_staff_id)";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@sid", s.SchoolId), ("@cls", s.ClassLabel), ("@sec", s.SectionLabel),
            ("@day", s.DayOfWeek), ("@period", s.PeriodNo), ("@time", s.TimeLabel),
            ("@subject", s.Subject), ("@room", s.Room), ("@staff", (object?)s.TeacherStaffId));
    }

    public async Task ClearSlotAsync(long schoolId, string className, string sectionName, int day, int period,
        CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn, @"
            DELETE FROM timetable_slot
            WHERE school_id=@sid AND class_label=@cls AND section_label=@sec
              AND day_of_week=@day AND period_no=@period", ct,
            ("@sid", schoolId), ("@cls", className), ("@sec", sectionName),
            ("@day", day), ("@period", period));
    }

    public async Task<int> CountSlotsOnDayAsync(long schoolId, int dayOfWeek, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM timetable_slot WHERE school_id=@sid AND day_of_week=@day", ct,
            ("@sid", schoolId), ("@day", dayOfWeek));
    }

    public async Task<IReadOnlyList<TimetableSlot>> GetForSectionSubjectAsync(long schoolId, string className,
        string sectionName, string subject, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {SlotColumns} {SlotFrom}
                     WHERE ts.school_id=@sid AND ts.class_label=@cls AND ts.section_label=@sec
                       AND ts.subject=@subject
                     ORDER BY ts.day_of_week, ts.period_no";
        return await DbHelper.QueryAsync(conn, sql, Map, ct,
            ("@sid", schoolId), ("@cls", className), ("@sec", sectionName), ("@subject", subject));
    }

    public async Task<int> RetargetSlotTeacherAsync(long schoolId, string className, string sectionName,
        string subject, long? staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ExecuteAsync(conn, @"
            UPDATE timetable_slot SET teacher_staff_id=@staff
            WHERE school_id=@sid AND class_label=@cls AND section_label=@sec AND subject=@subject", ct,
            ("@staff", (object?)staffId), ("@sid", schoolId), ("@cls", className),
            ("@sec", sectionName), ("@subject", subject));
    }

    public async Task<TimetableSlot?> FindTeacherClashAsync(long schoolId, long staffId, int day, int period,
        string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {SlotColumns} {SlotFrom}
                     WHERE ts.school_id=@sid AND ts.teacher_staff_id=@staff
                       AND ts.day_of_week=@day AND ts.period_no=@period
                       AND NOT (ts.class_label=@cls AND ts.section_label=@sec)
                     LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct,
            ("@sid", schoolId), ("@staff", staffId), ("@day", day), ("@period", period),
            ("@cls", className), ("@sec", sectionName));
    }

    public async Task<TimetableSlot?> FindRoomClashAsync(long schoolId, string room, int day, int period,
        string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {SlotColumns} {SlotFrom}
                     WHERE ts.school_id=@sid AND ts.room=@room
                       AND ts.day_of_week=@day AND ts.period_no=@period
                       AND NOT (ts.class_label=@cls AND ts.section_label=@sec)
                     LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct,
            ("@sid", schoolId), ("@room", room), ("@day", day), ("@period", period),
            ("@cls", className), ("@sec", sectionName));
    }

    private static TimetableSlot Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        ClassLabel = r.GetStringOrNull("class_label"),
        SectionLabel = r.GetStringOrNull("section_label"),
        DayOfWeek = r.GetInt("day_of_week"),
        PeriodNo = r.GetInt("period_no"),
        TimeLabel = r.GetStringOrNull("time_label"),
        Subject = r.GetStringOrNull("subject"),
        Room = r.GetStringOrNull("room"),
        TeacherStaffId = r.GetLongOrNull("teacher_staff_id"),
        TeacherName = r.GetStringOrNull("teacher_name"),
    };
}
