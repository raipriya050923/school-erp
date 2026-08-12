using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class TimetableRepository : ITimetableRepository
{
    private readonly IDbConnectionFactory _factory;
    public TimetableRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<TimetableSlot>> GetByTeacherAsync(long schoolId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT id, school_id, class_label, section_label, day_of_week, period_no, time_label, subject, room, teacher_staff_id
            FROM timetable_slot WHERE school_id=@sid AND teacher_staff_id=@tid
            ORDER BY day_of_week, period_no";
        return await DbHelper.QueryAsync(conn, sql, r => new TimetableSlot
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
        }, ct, ("@sid", schoolId), ("@tid", staffId));
    }
}
