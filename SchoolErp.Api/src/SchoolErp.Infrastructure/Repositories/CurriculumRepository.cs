using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class CurriculumRepository : ICurriculumRepository
{
    private readonly IDbConnectionFactory _factory;
    public CurriculumRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string AssignmentSelect = @"
        SELECT ta.id, ta.school_id, ta.academic_year_id, ta.staff_id, ta.class_id,
               ta.section_id, ta.subject_id,
               CONCAT(st.first_name, ' ', st.last_name) AS teacher_name,
               sub.name AS subject_name, sec.name AS section_name, c.name AS class_name
        FROM teacher_assignments ta
        JOIN staff st     ON st.id  = ta.staff_id
        JOIN subjects sub ON sub.id = ta.subject_id
        JOIN sections sec ON sec.id = ta.section_id
        JOIN classes c    ON c.id   = ta.class_id";

    public async Task<IReadOnlyList<ClassSubject>> GetClassSubjectsAsync(
        long schoolId, long academicYearId, long classId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT cs.id, cs.school_id, cs.academic_year_id, cs.class_id, cs.subject_id,
                   cs.is_optional, cs.full_marks, cs.pass_marks, s.name AS subject_name
            FROM class_subjects cs
            JOIN subjects s ON s.id = cs.subject_id
            WHERE cs.school_id=@sid AND cs.academic_year_id=@ay AND cs.class_id=@cid
            ORDER BY s.name";
        return await DbHelper.QueryAsync(conn, sql, r => new ClassSubject
        {
            Id = r.GetLong("id"),
            SchoolId = r.GetLong("school_id"),
            AcademicYearId = r.GetLong("academic_year_id"),
            ClassId = r.GetLong("class_id"),
            SubjectId = r.GetLong("subject_id"),
            IsOptional = r.GetInt("is_optional") == 1,
            FullMarks = (short?)r.GetIntOrNull("full_marks"),
            PassMarks = (short?)r.GetIntOrNull("pass_marks"),
            SubjectName = r.GetStringOrNull("subject_name"),
        }, ct, ("@sid", schoolId), ("@ay", academicYearId), ("@cid", classId));
    }

    /// <summary>
    /// Diffs against what is already stored rather than delete-all-then-insert, so a subject that
    /// stays in the set keeps its row id — and any marks configured against it survive the edit.
    /// </summary>
    public async Task SetClassSubjectsAsync(long schoolId, long academicYearId, long classId,
        IEnumerable<long> subjectIds, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var wanted = subjectIds.Distinct().ToList();

        var existing = await DbHelper.QueryAsync(conn,
            "SELECT subject_id FROM class_subjects WHERE academic_year_id=@ay AND class_id=@cid",
            r => r.GetLong("subject_id"), ct, ("@ay", academicYearId), ("@cid", classId));

        foreach (var id in wanted.Except(existing))
            await DbHelper.ExecuteAsync(conn, @"
                INSERT INTO class_subjects (school_id, academic_year_id, class_id, subject_id, is_optional)
                VALUES (@sid, @ay, @cid, @sub, 0)", ct,
                ("@sid", schoolId), ("@ay", academicYearId), ("@cid", classId), ("@sub", id));

        foreach (var id in existing.Except(wanted))
            await DbHelper.ExecuteAsync(conn,
                "DELETE FROM class_subjects WHERE academic_year_id=@ay AND class_id=@cid AND subject_id=@sub", ct,
                ("@ay", academicYearId), ("@cid", classId), ("@sub", id));
    }

    public async Task<IReadOnlyList<long>> GetAssignedSubjectIdsAsync(
        long academicYearId, long classId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            "SELECT DISTINCT subject_id FROM teacher_assignments WHERE academic_year_id=@ay AND class_id=@cid",
            r => r.GetLong("subject_id"), ct, ("@ay", academicYearId), ("@cid", classId));
    }

    public async Task<IReadOnlyList<TeacherAssignment>> GetAssignmentsForClassAsync(
        long schoolId, long academicYearId, long classId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = AssignmentSelect + @"
            WHERE ta.school_id=@sid AND ta.academic_year_id=@ay AND ta.class_id=@cid";
        return await DbHelper.QueryAsync(conn, sql, MapAssignment, ct,
            ("@sid", schoolId), ("@ay", academicYearId), ("@cid", classId));
    }

    public async Task<IReadOnlyList<TeacherAssignment>> GetAssignmentsForTeacherAsync(
        long schoolId, long academicYearId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = AssignmentSelect + @"
            WHERE ta.school_id=@sid AND ta.academic_year_id=@ay AND ta.staff_id=@staff
            ORDER BY c.numeric_level, c.name, sec.name, sub.name";
        return await DbHelper.QueryAsync(conn, sql, MapAssignment, ct,
            ("@sid", schoolId), ("@ay", academicYearId), ("@staff", staffId));
    }

    public async Task<int> ClearAssignmentsForClassAsync(long schoolId, long academicYearId, long classId,
        CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ExecuteAsync(conn, @"
            DELETE FROM teacher_assignments
            WHERE school_id=@sid AND academic_year_id=@ay AND class_id=@cid", ct,
            ("@sid", schoolId), ("@ay", academicYearId), ("@cid", classId));
    }

    /// <summary>
    /// One teacher per (section, subject): the existing row is removed first, so re-assigning
    /// replaces rather than accumulating. A null staffId simply clears the slot.
    /// </summary>
    public async Task AssignAsync(long schoolId, long academicYearId, long classId, long sectionId,
        long subjectId, long? staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn, @"
            DELETE FROM teacher_assignments
            WHERE school_id=@sid AND academic_year_id=@ay AND section_id=@sec AND subject_id=@sub", ct,
            ("@sid", schoolId), ("@ay", academicYearId), ("@sec", sectionId), ("@sub", subjectId));

        if (staffId is not { } staff) return;

        await DbHelper.ExecuteAsync(conn, @"
            INSERT INTO teacher_assignments
              (school_id, academic_year_id, staff_id, class_id, section_id, subject_id)
            VALUES (@sid, @ay, @staff, @cid, @sec, @sub)", ct,
            ("@sid", schoolId), ("@ay", academicYearId), ("@staff", staff),
            ("@cid", classId), ("@sec", sectionId), ("@sub", subjectId));
    }

    private static TeacherAssignment MapAssignment(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        AcademicYearId = r.GetLong("academic_year_id"),
        StaffId = r.GetLong("staff_id"),
        ClassId = r.GetLong("class_id"),
        SectionId = r.GetLong("section_id"),
        SubjectId = r.GetLong("subject_id"),
        TeacherName = r.GetStringOrNull("teacher_name"),
        SubjectName = r.GetStringOrNull("subject_name"),
        SectionName = r.GetStringOrNull("section_name"),
        ClassName = r.GetStringOrNull("class_name"),
    };
}
