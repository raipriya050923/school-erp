using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class StudentPortalRepository : IStudentPortalRepository
{
    private readonly IDbConnectionFactory _factory;
    public StudentPortalRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<Student?> GetProfileAsync(long schoolId, long studentId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"SELECT id, admission_no, roll_no, class_name, section_name, first_name, last_name, status
                             FROM students WHERE id=@id AND school_id=@sid AND deleted_at IS NULL";
        return await DbHelper.QuerySingleAsync(conn, sql, r => new Student
        {
            Id = r.GetLong("id"),
            AdmissionNo = r.GetString("admission_no"),
            RollNo = r.GetStringOrNull("roll_no"),
            ClassName = r.GetStringOrNull("class_name"),
            SectionName = r.GetStringOrNull("section_name"),
            FirstName = r.GetString("first_name"),
            LastName = r.GetString("last_name"),
            Status = r.GetString("status"),
        }, ct, ("@id", studentId), ("@sid", schoolId));
    }

    public async Task<IReadOnlyList<DailyAttendance>> GetAttendanceAsync(long schoolId, long studentId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"SELECT attendance_date, status FROM daily_attendance
                             WHERE school_id=@sid AND student_id=@stu ORDER BY attendance_date";
        return await DbHelper.QueryAsync(conn, sql, r => new DailyAttendance
        {
            AttendanceDate = r.GetDate("attendance_date"),
            Status = r.GetString("status"),
        }, ct, ("@sid", schoolId), ("@stu", studentId));
    }

    public async Task<IReadOnlyList<TeacherHomework>> GetHomeworkAsync(long schoolId, string className, string? classSection, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"SELECT id, title, subject, class_label, assigned_date, due_date, submitted_count, total_count, status
                             FROM teacher_homework WHERE school_id=@sid AND (class_label=@sec OR class_label=@cls)
                             ORDER BY due_date DESC";
        return await DbHelper.QueryAsync(conn, sql, r => new TeacherHomework
        {
            Id = r.GetLong("id"), Title = r.GetString("title"), Subject = r.GetStringOrNull("subject"),
            ClassLabel = r.GetStringOrNull("class_label"), AssignedDate = r.GetDateOrNull("assigned_date"),
            DueDate = r.GetDateOrNull("due_date"), Status = r.GetString("status"),
        }, ct, ("@sid", schoolId), ("@sec", classSection ?? ""), ("@cls", className));
    }

    public async Task<IReadOnlyList<TimetableSlot>> GetTimetableAsync(long schoolId, string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"SELECT day_of_week, period_no, time_label, subject, room FROM timetable_slot
                             WHERE school_id=@sid AND class_label=@cls AND section_label=@sec
                             ORDER BY day_of_week, period_no";
        return await DbHelper.QueryAsync(conn, sql, r => new TimetableSlot
        {
            DayOfWeek = r.GetInt("day_of_week"), PeriodNo = r.GetInt("period_no"),
            TimeLabel = r.GetStringOrNull("time_label"), Subject = r.GetStringOrNull("subject"), Room = r.GetStringOrNull("room"),
        }, ct, ("@sid", schoolId), ("@cls", className), ("@sec", sectionName));
    }

    public async Task<Exam?> GetPublishedExamAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Publishing results is an editorial decision, so this one really is the stored status —
        // an exam simply being over does not mean its marks are ready to show.
        const string sql = @"SELECT id, name FROM exam WHERE school_id=@sid AND status='result_published'
                             ORDER BY end_date DESC LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, r => new Exam { Id = r.GetLong("id"), Name = r.GetString("name") }, ct, ("@sid", schoolId));
    }

    public async Task<IReadOnlyList<StudentMark>> GetMarksAsync(long schoolId, long studentId, long examId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"SELECT subject, marks, full_marks FROM student_mark
                             WHERE school_id=@sid AND student_id=@stu AND exam_id=@eid ORDER BY subject";
        return await DbHelper.QueryAsync(conn, sql, r => new StudentMark
        {
            Subject = r.GetString("subject"),
            Marks = r.IsDBNull(r.GetOrdinal("marks")) ? null : r.GetDecimal("marks"),
            FullMarks = r.GetDecimal("full_marks"),
        }, ct, ("@sid", schoolId), ("@stu", studentId), ("@eid", examId));
    }

    public async Task<IReadOnlyList<ExamPaper>> GetUpcomingPapersAsync(long schoolId, string className, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Upcoming is a date question, not a stored-status one. This used to match
        // status IN ('scheduled','ongoing'), but the column is 'auto' on almost every row,
        // so it found papers only by accident.
        const string sql = @"SELECT p.subject, p.exam_date, p.time_label, p.room, p.class_label
                             FROM exam_paper p JOIN exam e ON e.id = p.exam_id
                             WHERE e.school_id=@sid AND e.status <> 'cancelled'
                               AND (e.end_date IS NULL OR e.end_date >= CURDATE())
                               AND p.class_label=@cls
                             ORDER BY p.exam_date";
        return await DbHelper.QueryAsync(conn, sql, r => new ExamPaper
        {
            Subject = r.GetString("subject"), ExamDate = r.GetDateOrNull("exam_date"),
            TimeLabel = r.GetStringOrNull("time_label"), Room = r.GetStringOrNull("room"), ClassLabel = r.GetStringOrNull("class_label"),
        }, ct, ("@sid", schoolId), ("@cls", className));
    }

    public async Task<IReadOnlyList<FeeInvoiceRow>> GetFeesAsync(long schoolId, long studentId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"SELECT id, invoice_no, month, amount, paid, due_date, status FROM fee_invoice
                             WHERE school_id=@sid AND student_id=@stu ORDER BY created_at DESC, id DESC";
        return await DbHelper.QueryAsync(conn, sql, r => new FeeInvoiceRow
        {
            Id = r.GetLong("id"), InvoiceNo = r.GetStringOrNull("invoice_no"), Month = r.GetStringOrNull("month"),
            Amount = r.GetDecimal("amount"), Paid = r.GetDecimal("paid"), DueDate = r.GetDateOrNull("due_date"), Status = r.GetString("status"),
        }, ct, ("@sid", schoolId), ("@stu", studentId));
    }

    public async Task<IReadOnlyList<Notice>> GetNoticesAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"SELECT id, school_id, title, body, audience, publish_date, is_published, created_by, created_at
                             FROM notices WHERE school_id=@sid AND is_published=1 ORDER BY publish_date DESC, id DESC LIMIT 30";
        return await DbHelper.QueryAsync(conn, sql, r => new Notice
        {
            Id = r.GetLong("id"), SchoolId = r.GetLong("school_id"), Title = r.GetString("title"),
            Body = r.GetString("body"), Audience = r.GetString("audience"), PublishDate = r.GetDate("publish_date"),
        }, ct, ("@sid", schoolId));
    }
}
