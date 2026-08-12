using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class ExamRepository : IExamRepository
{
    private readonly IDbConnectionFactory _factory;
    public ExamRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<Exam>> GetAllWithPapersAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var exams = await DbHelper.QueryAsync(conn,
            "SELECT id, school_id, name, type, start_date, end_date, classes, status FROM exam WHERE school_id=@sid ORDER BY start_date DESC, id DESC",
            MapExam, ct, ("@sid", schoolId));
        var papers = await DbHelper.QueryAsync(conn,
            @"SELECT p.id, p.exam_id, p.class_label, p.subject, p.exam_date, p.time_label, p.room, p.full_marks
              FROM exam_paper p JOIN exam e ON e.id = p.exam_id WHERE e.school_id=@sid ORDER BY p.exam_date",
            MapPaper, ct, ("@sid", schoolId));
        foreach (var e in exams) e.Papers = papers.Where(p => p.ExamId == e.Id).ToList();
        return exams;
    }

    public async Task<long> CreateExamAsync(Exam e, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"INSERT INTO exam (school_id, name, type, start_date, end_date, classes, status)
                             VALUES (@sid, @name, @type, @start, @end, @classes, 'scheduled')";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", e.SchoolId), ("@name", e.Name), ("@type", e.Type),
            ("@start", (object?)e.StartDate), ("@end", (object?)e.EndDate), ("@classes", e.Classes));
    }

    public async Task<long> AddPaperAsync(ExamPaper p, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"INSERT INTO exam_paper (exam_id, class_label, subject, exam_date, time_label, room, full_marks)
                             VALUES (@eid, @cls, @subject, @date, @time, @room, @full)";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@eid", p.ExamId), ("@cls", p.ClassLabel), ("@subject", p.Subject),
            ("@date", (object?)p.ExamDate), ("@time", p.TimeLabel), ("@room", p.Room), ("@full", p.FullMarks));
    }

    public async Task DeletePaperAsync(long schoolId, long paperId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"DELETE p FROM exam_paper p JOIN exam e ON e.id = p.exam_id WHERE p.id=@id AND e.school_id=@sid", ct,
            ("@id", paperId), ("@sid", schoolId));
    }

    public async Task<bool> PaperSubjectExistsAsync(long examId, string subject, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM exam_paper WHERE exam_id=@eid AND subject=@s", ct,
            ("@eid", examId), ("@s", subject)) > 0;
    }

    public async Task<IReadOnlyList<StudentMark>> GetMarksAsync(long schoolId, long examId, string className, string sectionName, string subject, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT s.id AS student_id, s.roll_no, CONCAT(s.first_name,' ',s.last_name) AS name, m.marks
            FROM students s
            LEFT JOIN student_mark m ON m.student_id = s.id AND m.exam_id=@eid AND m.subject=@subject
            WHERE s.school_id=@sid AND s.class_name=@cls AND s.section_name=@sec AND s.deleted_at IS NULL
            ORDER BY CAST(s.roll_no AS UNSIGNED), s.first_name LIMIT 80";
        return await DbHelper.QueryAsync(conn, sql, r => new StudentMark
        {
            StudentId = r.GetLong("student_id"),
            RollNo = r.GetStringOrNull("roll_no"),
            StudentName = r.GetString("name"),
            Marks = r.IsDBNull(r.GetOrdinal("marks")) ? null : r.GetDecimal("marks"),
        }, ct, ("@sid", schoolId), ("@eid", examId), ("@subject", subject), ("@cls", className), ("@sec", sectionName));
    }

    public async Task UpsertMarksAsync(long schoolId, long examId, string subject, int fullMarks,
        IEnumerable<(long studentId, decimal? marks)> entries, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO student_mark (school_id, exam_id, student_id, subject, marks, full_marks)
            VALUES (@sid, @eid, @stu, @subject, @marks, @full)
            ON DUPLICATE KEY UPDATE marks = VALUES(marks), full_marks = VALUES(full_marks)";
        foreach (var (studentId, marks) in entries)
            await DbHelper.ExecuteAsync(conn, sql, ct,
                ("@sid", schoolId), ("@eid", examId), ("@stu", studentId), ("@subject", subject),
                ("@marks", (object?)marks), ("@full", fullMarks));
    }

    private static Exam MapExam(IDataRecord r) => new()
    {
        Id = r.GetLong("id"), SchoolId = r.GetLong("school_id"), Name = r.GetString("name"),
        Type = r.GetStringOrNull("type"), StartDate = r.GetDateOrNull("start_date"),
        EndDate = r.GetDateOrNull("end_date"), Classes = r.GetStringOrNull("classes"), Status = r.GetString("status"),
    };
    private static ExamPaper MapPaper(IDataRecord r) => new()
    {
        Id = r.GetLong("id"), ExamId = r.GetLong("exam_id"), ClassLabel = r.GetStringOrNull("class_label"),
        Subject = r.GetString("subject"), ExamDate = r.GetDateOrNull("exam_date"),
        TimeLabel = r.GetStringOrNull("time_label"), Room = r.GetStringOrNull("room"), FullMarks = r.GetInt("full_marks"),
    };
}
