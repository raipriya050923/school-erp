using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Teacher;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Teacher;

public class TeacherPortalService : ITeacherPortalService
{
    private readonly ITeacherPortalRepository _repo;
    private readonly IAttendanceRepository _attendance;
    private readonly IExamRepository _exams;
    private readonly ITimetableRepository _timetable;
    private readonly ICurrentTeacher _me;

    public TeacherPortalService(ITeacherPortalRepository repo, IAttendanceRepository attendance,
        IExamRepository exams, ITimetableRepository timetable, ICurrentTeacher me)
    {
        _repo = repo;
        _attendance = attendance;
        _exams = exams;
        _timetable = timetable;
        _me = me;
    }

    /* ---- attendance ---- */
    public async Task<IReadOnlyList<AttendanceRowDto>> GetAttendanceAsync(string className, string sectionName, DateTime date, CancellationToken ct = default)
    {
        var rows = await _attendance.GetSectionAsync(_me.SchoolId, className, sectionName, date, ct);
        return rows.Select(r => new AttendanceRowDto(r.StudentId, r.RollNo, r.StudentName ?? "", r.Status)).ToList();
    }
    public Task SaveAttendanceAsync(SaveAttendanceDto dto, CancellationToken ct = default)
        => _attendance.UpsertAsync(_me.SchoolId, dto.ClassName, dto.SectionName, dto.Date,
            dto.Entries.Select(e => (e.StudentId, e.Status)), ct);

    /* ---- marks ---- */
    public async Task<IReadOnlyList<ExamDto>> GetExamsAsync(CancellationToken ct = default)
    {
        var exams = await _exams.GetAllWithPapersAsync(_me.SchoolId, ct);
        return exams.Select(ToExam).ToList();
    }
    public async Task<IReadOnlyList<MarkRowDto>> GetMarksAsync(long examId, string className, string sectionName, string subject, CancellationToken ct = default)
    {
        var rows = await _exams.GetMarksAsync(_me.SchoolId, examId, className, sectionName, subject, ct);
        return rows.Select(m => new MarkRowDto(m.StudentId, m.RollNo, m.StudentName ?? "", m.Marks)).ToList();
    }
    public Task SaveMarksAsync(SaveMarksDto dto, CancellationToken ct = default)
        => _exams.UpsertMarksAsync(_me.SchoolId, dto.ExamId, dto.Subject, dto.FullMarks,
            dto.Entries.Select(e => (e.StudentId, e.Marks)), ct);

    /* ---- timetable ---- */
    public async Task<IReadOnlyList<TimetableSlotDto>> GetTimetableAsync(CancellationToken ct = default)
    {
        var slots = await _timetable.GetByTeacherAsync(_me.SchoolId, _me.StaffId, ct);
        return slots.Select(s => new TimetableSlotDto(s.DayOfWeek, s.PeriodNo, s.TimeLabel,
            $"{s.ClassLabel}-{s.SectionLabel} · {s.Subject}", s.Room)).ToList();
    }

    private static ExamDto ToExam(Exam e) => new(
        e.Id, e.Name, e.Type, e.StartDate, e.EndDate, e.Classes, e.Status, e.Papers.Count,
        e.Papers.Select(p => new ExamPaperDto(p.Id, p.ClassLabel, p.Subject, p.ExamDate, p.TimeLabel, p.Room, p.FullMarks)).ToList());

    public async Task<TeacherProfileDto?> GetProfileAsync(CancellationToken ct = default)
    {
        var s = await _repo.GetProfileAsync(_me.SchoolId, _me.StaffId, ct);
        return s is null ? null : ToProfile(s);
    }

    public async Task<IReadOnlyList<MyClassDto>> GetMyClassesAsync(CancellationToken ct = default)
    {
        var profile = await _repo.GetProfileAsync(_me.SchoolId, _me.StaffId, ct);
        var subject = profile?.Specialization;
        var sections = await _repo.GetMyClassesAsync(_me.SchoolId, _me.StaffId, ct);
        return sections.Select(s => new MyClassDto(
            s.SectionId, s.ClassName, s.SectionName, subject, s.Room, s.StudentCount, true)).ToList();
    }

    public async Task<IReadOnlyList<RosterStudentDto>> GetRosterAsync(string className, string sectionName, CancellationToken ct = default)
    {
        var rows = await _repo.GetRosterAsync(_me.SchoolId, className, sectionName, ct);
        return rows.Select(s => new RosterStudentDto(s.Id, s.RollNo, $"{s.FirstName} {s.LastName}".Trim())).ToList();
    }

    public async Task<IReadOnlyList<HomeworkDto>> GetHomeworkAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetHomeworkAsync(_me.SchoolId, _me.StaffId, ct);
        return rows.Select(ToHomework).ToList();
    }

    public async Task<long> CreateHomeworkAsync(CreateHomeworkDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Title))
            throw new ValidationException("Homework title is required.");
        var profile = await _repo.GetProfileAsync(_me.SchoolId, _me.StaffId, ct);
        var h = new TeacherHomework
        {
            SchoolId = _me.SchoolId,
            TeacherStaffId = _me.StaffId,
            Title = dto.Title.Trim(),
            Subject = string.IsNullOrWhiteSpace(dto.Subject) ? profile?.Specialization : dto.Subject,
            ClassLabel = dto.ClassLabel,
            AssignedDate = DateTime.UtcNow,
            DueDate = dto.DueDate,
            SubmittedCount = 0,
            TotalCount = dto.TotalCount,
            Status = "open",
        };
        return await _repo.CreateHomeworkAsync(h, ct);
    }

    public async Task<TeacherDashboardDto> GetDashboardAsync(CancellationToken ct = default)
    {
        var profile = await _repo.GetProfileAsync(_me.SchoolId, _me.StaffId, ct)
                      ?? throw new NotFoundException("Teacher profile not found.");
        var classes = await _repo.GetMyClassesAsync(_me.SchoolId, _me.StaffId, ct);
        var homework = await _repo.GetHomeworkAsync(_me.SchoolId, _me.StaffId, ct);

        var studentsTaught = classes.Sum(c => c.StudentCount);
        var toGrade = homework.Where(h => h.Status is "open" or "grading").Sum(h => Math.Max(0, h.SubmittedCount));
        var openCount = homework.Count(h => h.Status == "open");

        return new TeacherDashboardDto(
            ToProfile(profile),
            classes.Count,
            studentsTaught,
            toGrade,
            openCount,
            homework.Take(4).Select(ToHomework).ToList());
    }

    private static TeacherProfileDto ToProfile(StaffMember s) => new(
        s.Id, s.EmployeeCode, $"{s.FirstName} {s.LastName}".Trim(), s.Specialization,
        s.ClassesTaught, s.Phone, s.Email, s.Qualification, s.JoiningDate);

    private static HomeworkDto ToHomework(TeacherHomework h) => new(
        h.Id, h.Title, h.Subject, h.ClassLabel, h.AssignedDate, h.DueDate,
        h.SubmittedCount, h.TotalCount, h.Status);
}
