using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class ExamResultRepository : IExamResultRepository
{
    private readonly IDbConnectionFactory _factory;
    public ExamResultRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<GradeBand>> GetGradeScaleAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn, @"
            SELECT grade, min_percent, max_percent, grade_point, remarks
            FROM grade_scales WHERE school_id=@sid
            ORDER BY min_percent DESC",
            r => new GradeBand
            {
                Grade = r.GetString("grade"),
                MinPercent = r.GetDecimal("min_percent"),
                MaxPercent = r.GetDecimal("max_percent"),
                GradePoint = r.IsDBNull(r.GetOrdinal("grade_point")) ? null : r.GetDecimal("grade_point"),
                Remarks = r.GetStringOrNull("remarks"),
            }, ct, ("@sid", schoolId));
    }

    public async Task<int> RecomputeSectionAsync(long schoolId, long examId, string className, string sectionName,
        IReadOnlyList<GradeBand> scale, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);

        // The papers this class sits. A paper with no class label, or the literal 'All' the old
        // form wrote, applies to every class.
        var papers = await DbHelper.QueryAsync(conn, @"
            SELECT p.subject, p.full_marks
            FROM exam_paper p
            JOIN exam e ON e.id = p.exam_id
            WHERE p.exam_id = @eid AND e.school_id = @sid
              AND (p.class_label IS NULL OR p.class_label = '' OR p.class_label = 'All'
                   OR p.class_label = @cls)",
            r => (Subject: r.GetString("subject"), Full: r.GetDecimal("full_marks")), ct,
            ("@sid", schoolId), ("@eid", examId), ("@cls", className));

        var subjectsTotal = papers.Count;
        var fullMarks = papers.Sum(p => p.Full);

        // Students of the section, with whatever marks exist. LEFT JOIN so a student with none
        // still gets a row — a missing result reads as "not computed", which is worse than zero.
        var rows = await DbHelper.QueryAsync(conn, @"
            SELECT s.id AS student_id, m.subject, m.marks
            FROM students s
            LEFT JOIN student_mark m ON m.student_id = s.id AND m.exam_id = @eid AND m.marks IS NOT NULL
            WHERE s.school_id = @sid AND s.class_name = @cls AND s.section_name = @sec
              AND s.deleted_at IS NULL",
            r => (StudentId: r.GetLong("student_id"),
                  Subject: r.GetStringOrNull("subject"),
                  Marks: r.IsDBNull(r.GetOrdinal("marks")) ? (decimal?)null : r.GetDecimal("marks")), ct,
            ("@sid", schoolId), ("@eid", examId), ("@cls", className), ("@sec", sectionName));

        var written = 0;
        foreach (var group in rows.GroupBy(r => r.StudentId))
        {
            // Only marks against a paper this class actually sits: a mark left over from a paper
            // since deleted must not inflate the total.
            var scored = group
                .Where(x => x.Subject is not null && x.Marks.HasValue
                            && papers.Any(p => string.Equals(p.Subject, x.Subject, StringComparison.OrdinalIgnoreCase)))
                .ToList();

            var obtained = scored.Sum(x => x.Marks!.Value);
            var entered = scored.Select(x => x.Subject!).Distinct(StringComparer.OrdinalIgnoreCase).Count();
            var complete = subjectsTotal > 0 && entered >= subjectsTotal;
            var percent = fullMarks > 0 ? Math.Round(obtained * 100m / fullMarks, 2, MidpointRounding.AwayFromZero) : 0m;

            await DbHelper.ExecuteAsync(conn, @"
                INSERT INTO exam_result
                    (school_id, exam_id, student_id, class_label, section_label,
                     obtained, full_marks, percent, grade, subjects_total, subjects_entered, is_complete)
                VALUES (@sid, @eid, @stu, @cls, @sec, @obt, @full, @pct, @grade, @total, @entered, @complete)
                ON DUPLICATE KEY UPDATE
                    class_label = VALUES(class_label), section_label = VALUES(section_label),
                    obtained = VALUES(obtained), full_marks = VALUES(full_marks),
                    percent = VALUES(percent), grade = VALUES(grade),
                    subjects_total = VALUES(subjects_total), subjects_entered = VALUES(subjects_entered),
                    is_complete = VALUES(is_complete)", ct,
                ("@sid", schoolId), ("@eid", examId), ("@stu", group.Key),
                ("@cls", className), ("@sec", sectionName),
                ("@obt", obtained), ("@full", fullMarks), ("@pct", percent),
                ("@grade", GradeFor(percent, scale)),
                ("@total", subjectsTotal), ("@entered", entered), ("@complete", complete));
            written++;
        }
        return written;
    }

    /// <summary>
    /// The band a percentage falls in. Bands come from the school's own scale; with none
    /// configured no grade is claimed rather than one being invented.
    /// </summary>
    private static string? GradeFor(decimal percent, IReadOnlyList<GradeBand> scale) =>
        scale.FirstOrDefault(b => percent >= b.MinPercent && percent <= b.MaxPercent)?.Grade;

    public async Task<IReadOnlyList<ExamResultRow>> GetSectionResultsAsync(long schoolId, long examId,
        string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn, @"
            SELECT r.id, r.school_id, r.exam_id, r.student_id, r.class_label, r.section_label,
                   r.obtained, r.full_marks, r.percent, r.grade,
                   r.subjects_total, r.subjects_entered, r.is_complete, r.computed_at,
                   s.roll_no, CONCAT(s.first_name,' ',s.last_name) AS student_name
            FROM exam_result r
            JOIN students s ON s.id = r.student_id
            WHERE r.school_id=@sid AND r.exam_id=@eid
              AND r.class_label=@cls AND r.section_label=@sec",
            r => new ExamResultRow
            {
                Id = r.GetLong("id"),
                SchoolId = r.GetLong("school_id"),
                ExamId = r.GetLong("exam_id"),
                StudentId = r.GetLong("student_id"),
                ClassLabel = r.GetStringOrNull("class_label"),
                SectionLabel = r.GetStringOrNull("section_label"),
                Obtained = r.GetDecimal("obtained"),
                FullMarks = r.GetDecimal("full_marks"),
                Percent = r.GetDecimal("percent"),
                Grade = r.GetStringOrNull("grade"),
                SubjectsTotal = r.GetInt("subjects_total"),
                SubjectsEntered = r.GetInt("subjects_entered"),
                IsComplete = r.GetBool("is_complete"),
                ComputedAt = r.GetDate("computed_at"),
                RollNo = r.GetStringOrNull("roll_no"),
                StudentName = r.GetStringOrNull("student_name"),
            }, ct, ("@sid", schoolId), ("@eid", examId), ("@cls", className), ("@sec", sectionName));
    }

    public async Task<ExamSectionApproval> GetApprovalAsync(long schoolId, long examId, string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var row = await DbHelper.QuerySingleAsync(conn, ApprovalSql + @"
            WHERE a.school_id=@sid AND a.exam_id=@eid AND a.class_label=@cls AND a.section_label=@sec",
            MapApproval, ct, ("@sid", schoolId), ("@eid", examId), ("@cls", className), ("@sec", sectionName));

        // No row yet simply means nobody has signed off, which is the same as pending.
        row ??= new ExamSectionApproval
        {
            ExamId = examId, ClassLabel = className, SectionLabel = sectionName, Status = "pending",
        };

        // QuerySingleAsync is constrained to reference types, so the two counts come back as a list.
        var counts = await DbHelper.QueryAsync(conn, @"
            SELECT (SELECT COUNT(*) FROM students stu
                     WHERE stu.school_id=@sid AND stu.class_name=@cls AND stu.section_name=@sec
                       AND stu.deleted_at IS NULL) AS students,
                   (SELECT COALESCE(SUM(is_complete), 0) FROM exam_result
                     WHERE school_id=@sid AND exam_id=@eid
                       AND class_label=@cls AND section_label=@sec) AS complete",
            r => new[] { r.GetInt("students"), r.GetInt("complete") }, ct,
            ("@sid", schoolId), ("@eid", examId), ("@cls", className), ("@sec", sectionName));
        row.StudentCount = counts.FirstOrDefault()?[0] ?? 0;
        row.CompleteCount = counts.FirstOrDefault()?[1] ?? 0;
        return row;
    }

    public async Task<IReadOnlyList<ExamSectionApproval>> GetExamApprovalsAsync(long schoolId, long examId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Driven from the sections that have students, not from the approval table: a section
        // nobody has signed off yet still has to appear on the admin's checklist.
        return await DbHelper.QueryAsync(conn, @"
            SELECT c.name AS class_label, sec.name AS section_label,
                   COALESCE(a.status, 'pending') AS status,
                   a.approved_by, a.approved_at, a.remarks,
                   CONCAT(st.first_name, ' ', st.last_name) AS approved_by_name,
                   -- Counted from students, not from exam_result: a section nobody has opened
                   -- yet has no result rows, and a count of 0 of 0 would read as finished.
                   (SELECT COUNT(*) FROM students stu
                     WHERE stu.school_id = sec.school_id AND stu.class_name = c.name
                       AND stu.section_name = sec.name AND stu.deleted_at IS NULL) AS students,
                   (SELECT COALESCE(SUM(r.is_complete), 0) FROM exam_result r
                     WHERE r.school_id = sec.school_id AND r.exam_id = @eid
                       AND r.class_label = c.name AND r.section_label = sec.name) AS complete
            FROM sections sec
            JOIN classes c ON c.id = sec.class_id
            LEFT JOIN exam_section_result a
                   ON a.exam_id = @eid AND a.class_label = c.name AND a.section_label = sec.name
            LEFT JOIN staff st ON st.id = a.approved_by
            WHERE sec.school_id = @sid
              AND EXISTS (
                    SELECT 1 FROM exam_paper p
                    WHERE p.exam_id = @eid
                      AND (p.class_label IS NULL OR p.class_label = '' OR p.class_label = 'All'
                           OR p.class_label = c.name))
              AND EXISTS (
                    SELECT 1 FROM students stu
                    WHERE stu.school_id = sec.school_id AND stu.class_name = c.name
                      AND stu.section_name = sec.name AND stu.deleted_at IS NULL)
              -- An empty section has no result to approve, so listing it would block publishing
              -- for good: nobody can ever sign off a sheet with no students on it.
              AND EXISTS (
                    SELECT 1 FROM students stu
                    WHERE stu.school_id = sec.school_id AND stu.class_name = c.name
                      AND stu.section_name = sec.name AND stu.deleted_at IS NULL)
            ORDER BY c.numeric_level, c.name, sec.name",
            r => new ExamSectionApproval
            {
                ExamId = examId,
                ClassLabel = r.GetString("class_label"),
                SectionLabel = r.GetString("section_label"),
                Status = r.GetString("status"),
                ApprovedBy = r.GetLongOrNull("approved_by"),
                ApprovedByName = r.GetStringOrNull("approved_by_name"),
                ApprovedAt = r.GetDateOrNull("approved_at"),
                Remarks = r.GetStringOrNull("remarks"),
                StudentCount = r.GetInt("students"),
                CompleteCount = r.GetInt("complete"),
            }, ct, ("@sid", schoolId), ("@eid", examId));
    }

    public async Task SetApprovalAsync(long schoolId, long examId, string className, string sectionName,
        string status, long? approvedBy, string? remarks, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn, @"
            INSERT INTO exam_section_result
                (school_id, exam_id, class_label, section_label, status, approved_by, approved_at, remarks)
            VALUES (@sid, @eid, @cls, @sec, @st, @by, @at, @rem)
            ON DUPLICATE KEY UPDATE
                status = VALUES(status), approved_by = VALUES(approved_by),
                approved_at = VALUES(approved_at), remarks = VALUES(remarks)", ct,
            ("@sid", schoolId), ("@eid", examId), ("@cls", className), ("@sec", sectionName),
            ("@st", status), ("@by", (object?)approvedBy),
            ("@at", status == "approved" ? DateTime.UtcNow : (object?)null), ("@rem", remarks));
    }

    public async Task ResetApprovalAsync(long schoolId, long examId, string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Only touches an approved row: writing a pending row for a section nobody has looked at
        // would fill the table with noise.
        await DbHelper.ExecuteAsync(conn, @"
            UPDATE exam_section_result
            SET status = 'pending', approved_by = NULL, approved_at = NULL
            WHERE school_id=@sid AND exam_id=@eid AND class_label=@cls AND section_label=@sec
              AND status = 'approved'", ct,
            ("@sid", schoolId), ("@eid", examId), ("@cls", className), ("@sec", sectionName));
    }

    private const string ApprovalSql = @"
        SELECT a.class_label, a.section_label, a.status, a.approved_by, a.approved_at, a.remarks,
               CONCAT(st.first_name, ' ', st.last_name) AS approved_by_name
        FROM exam_section_result a
        LEFT JOIN staff st ON st.id = a.approved_by";

    private static ExamSectionApproval MapApproval(IDataRecord r) => new()
    {
        ClassLabel = r.GetString("class_label"),
        SectionLabel = r.GetString("section_label"),
        Status = r.GetString("status"),
        ApprovedBy = r.GetLongOrNull("approved_by"),
        ApprovedByName = r.GetStringOrNull("approved_by_name"),
        ApprovedAt = r.GetDateOrNull("approved_at"),
        Remarks = r.GetStringOrNull("remarks"),
    };
}
