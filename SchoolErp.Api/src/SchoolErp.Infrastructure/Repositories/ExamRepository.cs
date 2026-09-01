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

    public async Task UpdateExamAsync(Exam e, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"UPDATE exam SET name=@name, type=@type, start_date=@start, end_date=@end, classes=@classes
              WHERE id=@id AND school_id=@sid", ct,
            ("@name", e.Name), ("@type", e.Type), ("@start", (object?)e.StartDate),
            ("@end", (object?)e.EndDate), ("@classes", e.Classes), ("@id", e.Id), ("@sid", e.SchoolId));
    }

    public async Task DeleteExamAsync(long schoolId, long examId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // exam_paper and student_mark were created without foreign keys, so nothing cascades for us.
        await DbHelper.ExecuteAsync(conn,
            "DELETE FROM student_mark WHERE exam_id=@id AND school_id=@sid", ct,
            ("@id", examId), ("@sid", schoolId));
        await DbHelper.ExecuteAsync(conn,
            "DELETE p FROM exam_paper p JOIN exam e ON e.id = p.exam_id WHERE p.exam_id=@id AND e.school_id=@sid", ct,
            ("@id", examId), ("@sid", schoolId));
        await DbHelper.ExecuteAsync(conn,
            "DELETE FROM exam WHERE id=@id AND school_id=@sid", ct,
            ("@id", examId), ("@sid", schoolId));
    }

    public async Task<Exam?> GetAsync(long schoolId, long examId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            "SELECT id, school_id, name, type, start_date, end_date, classes, status FROM exam WHERE id=@id AND school_id=@sid",
            MapExam, ct, ("@id", examId), ("@sid", schoolId));
    }

    public async Task SetStatusAsync(long schoolId, long examId, string status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE exam SET status=@st WHERE id=@id AND school_id=@sid", ct,
            ("@st", status), ("@id", examId), ("@sid", schoolId));
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

    public async Task<bool> PaperSubjectExistsAsync(long examId, string? classLabel, string subject, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // <=> so two NULL class labels compare equal; = would make every such row look distinct.
        return await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM exam_paper WHERE exam_id=@eid AND class_label <=> @cls AND subject=@s", ct,
            ("@eid", examId), ("@cls", classLabel), ("@s", subject)) > 0;
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

    public async Task<int> UpsertMarksAsync(long schoolId, long examId, string className, string sectionName,
        string subject, int fullMarks, IEnumerable<(long studentId, decimal? marks)> entries, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // SELECT ... WHERE rather than VALUES: the row is only written if the id really is a
        // student of this school in this section. A plain INSERT trusted whatever ids were posted,
        // so a teacher could file marks against students of another school entirely.
        const string sql = @"
            INSERT INTO student_mark (school_id, exam_id, student_id, subject, marks, full_marks)
            SELECT @sid, @eid, s.id, @subject, @marks, @full
            FROM students s
            WHERE s.id = @stu AND s.school_id = @sid
              AND s.class_name = @cls AND s.section_name = @sec AND s.deleted_at IS NULL
            ON DUPLICATE KEY UPDATE marks = VALUES(marks), full_marks = VALUES(full_marks)";
        var applied = 0;
        foreach (var (studentId, marks) in entries)
        {
            // MySQL reports 1 for an insert and 0 or 2 for a duplicate-key update; anything
            // non-zero means the student matched.
            var rows = await DbHelper.ExecuteAsync(conn, sql, ct,
                ("@sid", schoolId), ("@eid", examId), ("@stu", studentId), ("@subject", subject),
                ("@marks", (object?)marks), ("@full", fullMarks),
                ("@cls", className), ("@sec", sectionName));
            if (rows > 0) applied++;
        }
        return applied;
    }

    public async Task<IReadOnlyList<StudentMark>> GetSectionMarksAsync(long schoolId, long examId,
        string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // LEFT JOIN with no subject filter: one pass returns every student and every mark they
        // already have, so the grid needs one round trip rather than one per subject.
        const string sql = @"
            SELECT s.id AS student_id, s.roll_no, CONCAT(s.first_name,' ',s.last_name) AS name,
                   COALESCE(m.subject, '') AS subject, m.marks
            FROM students s
            LEFT JOIN student_mark m ON m.student_id = s.id AND m.exam_id = @eid
            WHERE s.school_id = @sid AND s.class_name = @cls AND s.section_name = @sec
              AND s.deleted_at IS NULL
            ORDER BY CAST(s.roll_no AS UNSIGNED), s.first_name, subject
            LIMIT 2000";
        return await DbHelper.QueryAsync(conn, sql, r => new StudentMark
        {
            StudentId = r.GetLong("student_id"),
            RollNo = r.GetStringOrNull("roll_no"),
            StudentName = r.GetString("name"),
            Subject = r.GetString("subject"),
            Marks = r.IsDBNull(r.GetOrdinal("marks")) ? null : r.GetDecimal("marks"),
        }, ct, ("@sid", schoolId), ("@eid", examId), ("@cls", className), ("@sec", sectionName));
    }

    public async Task<IReadOnlyList<MarksProgressRow>> GetMarksProgressAsync(long schoolId, long examId,
        string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // A paper with no class_label applies to every class the exam covers, so it must not be
        // filtered out. Marks are counted through students so another section cannot inflate it.
        const string sql = @"
            SELECT p.subject, p.full_marks, p.exam_date,
                   (SELECT COUNT(*)
                      FROM student_mark m
                      JOIN students s ON s.id = m.student_id
                     WHERE m.exam_id = p.exam_id AND m.subject = p.subject AND m.marks IS NOT NULL
                       AND s.school_id = @sid AND s.class_name = @cls AND s.section_name = @sec
                       AND s.deleted_at IS NULL) AS entered,
                   (SELECT COUNT(*) FROM students s2
                     WHERE s2.school_id = @sid AND s2.class_name = @cls AND s2.section_name = @sec
                       AND s2.deleted_at IS NULL) AS total
            FROM exam_paper p
            JOIN exam e ON e.id = p.exam_id
            WHERE p.exam_id = @eid AND e.school_id = @sid
              -- 'All' is what the old Add Subject form wrote for an all-classes exam; treat it
              -- as the wildcard it was meant to be rather than a class nobody is in.
              AND (p.class_label IS NULL OR p.class_label = '' OR p.class_label = 'All'
                   OR p.class_label = @cls)
            ORDER BY p.exam_date, p.subject";
        return await DbHelper.QueryAsync(conn, sql, r => new MarksProgressRow
        {
            Subject = r.GetString("subject"),
            FullMarks = r.GetInt("full_marks"),
            ExamDate = r.GetDateOrNull("exam_date"),
            Entered = r.GetInt("entered"),
            Total = r.GetInt("total"),
        }, ct, ("@sid", schoolId), ("@eid", examId), ("@cls", className), ("@sec", sectionName));
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
