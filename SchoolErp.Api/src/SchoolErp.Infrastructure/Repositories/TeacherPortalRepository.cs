using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class TeacherPortalRepository : ITeacherPortalRepository
{
    private readonly IDbConnectionFactory _factory;
    public TeacherPortalRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<StaffMember?> GetProfileAsync(long schoolId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT id, school_id, user_id, employee_code, staff_type, first_name, last_name, gender, dob,
                   email, phone, address, city, state, pincode, qualification, specialization,
                   joining_date, status, created_at
            FROM staff WHERE id=@id AND school_id=@sid AND deleted_at IS NULL";
        return await DbHelper.QuerySingleAsync(conn, sql, MapStaff, ct, ("@id", staffId), ("@sid", schoolId));
    }

    public async Task<IReadOnlyList<TeacherClassRow>> GetMyClassesAsync(long schoolId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // sections where this teacher is the class teacher, with live student counts
        const string sql = @"
            SELECT sec.id AS section_id, sec.name AS section_name, c.name AS class_name, sec.room_no,
                   (SELECT COUNT(*) FROM students stu
                     WHERE stu.school_id = sec.school_id AND stu.class_name = c.name
                       AND stu.section_name = sec.name AND stu.deleted_at IS NULL) AS student_count
            FROM sections sec
            JOIN classes c ON c.id = sec.class_id
            WHERE sec.school_id=@sid AND sec.class_teacher_id=@tid
            ORDER BY c.numeric_level, sec.name";
        return await DbHelper.QueryAsync(conn, sql, r => new TeacherClassRow
        {
            SectionId = r.GetLong("section_id"),
            ClassName = r.GetString("class_name"),
            SectionName = r.GetString("section_name"),
            Room = r.GetStringOrNull("room_no"),
            StudentCount = r.GetInt("student_count"),
        }, ct, ("@sid", schoolId), ("@tid", staffId));
    }

    public async Task<IReadOnlyList<TeacherAssignmentRow>> GetMyAssignmentsAsync(long schoolId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Pinned to the current academic year: an assignment from a past year is history, not a
        // licence to edit this year's marks.
        const string sql = @"
            SELECT sec.id AS section_id, sec.name AS section_name, c.name AS class_name,
                   sub.id AS subject_id, sub.name AS subject,
                   (SELECT COUNT(*) FROM students stu
                     WHERE stu.school_id = sec.school_id AND stu.class_name = c.name
                       AND stu.section_name = sec.name AND stu.deleted_at IS NULL) AS student_count
            FROM teacher_assignments ta
            JOIN sections sec ON sec.id = ta.section_id
            JOIN classes c ON c.id = sec.class_id
            JOIN subjects sub ON sub.id = ta.subject_id
            JOIN academic_years ay ON ay.id = ta.academic_year_id AND ay.is_current = 1
            WHERE ta.school_id = @sid AND ta.staff_id = @tid
            ORDER BY c.numeric_level, c.name, sec.name, sub.name";
        return await DbHelper.QueryAsync(conn, sql, r => new TeacherAssignmentRow
        {
            SectionId = r.GetLong("section_id"),
            ClassName = r.GetString("class_name"),
            SectionName = r.GetString("section_name"),
            SubjectId = r.GetLong("subject_id"),
            Subject = r.GetString("subject"),
            StudentCount = r.GetInt("student_count"),
        }, ct, ("@sid", schoolId), ("@tid", staffId));
    }

    public async Task<IReadOnlyList<SubjectTeacherRow>> GetSectionSubjectTeachersAsync(long schoolId, string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT sub.name AS subject,
                   TRIM(CONCAT(COALESCE(s.first_name, ''), ' ', COALESCE(s.last_name, ''))) AS teacher_name
            FROM teacher_assignments ta
            JOIN sections sec ON sec.id = ta.section_id
            JOIN classes c ON c.id = sec.class_id
            JOIN subjects sub ON sub.id = ta.subject_id
            JOIN academic_years ay ON ay.id = ta.academic_year_id AND ay.is_current = 1
            LEFT JOIN staff s ON s.id = ta.staff_id
            WHERE ta.school_id = @sid AND c.name = @cls AND sec.name = @sec
            ORDER BY sub.name";
        return await DbHelper.QueryAsync(conn, sql, r => new SubjectTeacherRow
        {
            Subject = r.GetString("subject"),
            TeacherName = r.GetStringOrNull("teacher_name"),
        }, ct, ("@sid", schoolId), ("@cls", className), ("@sec", sectionName));
    }

    public async Task<bool> IsClassTeacherOfAsync(long schoolId, long staffId, string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ScalarLongAsync(conn, @"
            SELECT COUNT(*)
            FROM sections sec
            JOIN classes c ON c.id = sec.class_id
            WHERE sec.school_id = @sid AND sec.class_teacher_id = @tid
              AND c.name = @cls AND sec.name = @sec", ct,
            ("@sid", schoolId), ("@tid", staffId), ("@cls", className), ("@sec", sectionName)) > 0;
    }

    public async Task<IReadOnlyList<Student>> GetRosterAsync(long schoolId, string className, string sectionName, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT id, roll_no, first_name, last_name FROM students
            WHERE school_id=@sid AND class_name=@cls AND section_name=@sec AND deleted_at IS NULL
            ORDER BY CAST(roll_no AS UNSIGNED), first_name LIMIT 80";
        return await DbHelper.QueryAsync(conn, sql, r => new Student
        {
            Id = r.GetLong("id"),
            RollNo = r.GetStringOrNull("roll_no"),
            FirstName = r.GetString("first_name"),
            LastName = r.GetString("last_name"),
        }, ct, ("@sid", schoolId), ("@cls", className), ("@sec", sectionName));
    }

    public async Task<IReadOnlyList<TeacherHomework>> GetHomeworkAsync(long schoolId, long staffId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT id, school_id, teacher_staff_id, title, subject, class_label, assigned_date, due_date,
                   submitted_count, total_count, status, created_at
            FROM teacher_homework WHERE school_id=@sid AND teacher_staff_id=@tid
            ORDER BY due_date DESC, id DESC";
        return await DbHelper.QueryAsync(conn, sql, MapHomework, ct, ("@sid", schoolId), ("@tid", staffId));
    }

    public async Task<long> CreateHomeworkAsync(TeacherHomework h, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO teacher_homework
              (school_id, teacher_staff_id, title, subject, class_label, assigned_date, due_date,
               submitted_count, total_count, status, created_at)
            VALUES
              (@sid, @tid, @title, @subject, @cls, @assigned, @due, 0, @total, @status, NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", h.SchoolId), ("@tid", h.TeacherStaffId), ("@title", h.Title), ("@subject", h.Subject),
            ("@cls", h.ClassLabel), ("@assigned", (object?)h.AssignedDate), ("@due", (object?)h.DueDate),
            ("@total", h.TotalCount), ("@status", h.Status));
    }

    private static StaffMember MapStaff(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        UserId = r.GetLongOrNull("user_id"),
        EmployeeCode = r.GetString("employee_code"),
        StaffType = r.GetString("staff_type"),
        FirstName = r.GetString("first_name"),
        LastName = r.GetString("last_name"),
        Gender = r.GetStringOrNull("gender"),
        Dob = r.GetDateOrNull("dob"),
        Email = r.GetStringOrNull("email"),
        Phone = r.GetStringOrNull("phone"),
        Address = r.GetStringOrNull("address"),
        City = r.GetStringOrNull("city"),
        Qualification = r.GetStringOrNull("qualification"),
        Specialization = r.GetStringOrNull("specialization"),
        JoiningDate = r.GetDateOrNull("joining_date"),
        Status = r.GetString("status"),
    };

    private static TeacherHomework MapHomework(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        TeacherStaffId = r.GetLong("teacher_staff_id"),
        Title = r.GetString("title"),
        Subject = r.GetStringOrNull("subject"),
        ClassLabel = r.GetStringOrNull("class_label"),
        AssignedDate = r.GetDateOrNull("assigned_date"),
        DueDate = r.GetDateOrNull("due_date"),
        SubmittedCount = r.GetInt("submitted_count"),
        TotalCount = r.GetInt("total_count"),
        Status = r.GetString("status"),
        CreatedAt = r.GetDate("created_at"),
    };
}
