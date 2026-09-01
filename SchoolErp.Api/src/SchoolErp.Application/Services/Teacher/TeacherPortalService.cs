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
    private readonly IExamResultRepository _results;
    private readonly ICurrentTeacher _me;

    public TeacherPortalService(ITeacherPortalRepository repo, IAttendanceRepository attendance,
        IExamRepository exams, ITimetableRepository timetable, IExamResultRepository results,
        ICurrentTeacher me)
    {
        _repo = repo;
        _attendance = attendance;
        _exams = exams;
        _timetable = timetable;
        _results = results;
        _me = me;
    }

    /// <summary>
    /// Rewrites the stored result rows for a section and, if it had been signed off, drops it back
    /// to pending. Called after every save of marks: a stored result that lags the marks behind it
    /// is worse than no stored result at all.
    /// </summary>
    private async Task RecomputeResultsAsync(long examId, string className, string sectionName, CancellationToken ct)
    {
        var scale = await _results.GetGradeScaleAsync(_me.SchoolId, ct);
        await _results.RecomputeSectionAsync(_me.SchoolId, examId, className, sectionName, scale, ct);
        await _results.ResetApprovalAsync(_me.SchoolId, examId, className, sectionName, ct);
    }

    /* ---- attendance ---- */
    //
    // Daily attendance is a class-teacher duty, so it is scoped to the sections this teacher is
    // class teacher of. The section used to come straight from the query string and be trusted:
    // the dropdown offered only their own, but any section name would have been accepted.

    public async Task<IReadOnlyList<AttendanceRowDto>> GetAttendanceAsync(string className, string sectionName, DateTime date, CancellationToken ct = default)
    {
        await AssertClassTeacherAsync(className, sectionName, ct);
        var rows = await _attendance.GetSectionAsync(_me.SchoolId, className, sectionName, date, ct);
        return rows.Select(r => new AttendanceRowDto(r.StudentId, r.RollNo, r.StudentName ?? "", r.Status)).ToList();
    }

    public async Task SaveAttendanceAsync(SaveAttendanceDto dto, CancellationToken ct = default)
    {
        await AssertClassTeacherAsync(dto.ClassName, dto.SectionName, ct);
        await _attendance.UpsertAsync(_me.SchoolId, dto.ClassName, dto.SectionName, dto.Date,
            dto.Entries.Select(e => (e.StudentId, e.Status)), ct);
    }

    private async Task AssertClassTeacherAsync(string className, string sectionName, CancellationToken ct)
    {
        if (!await _repo.IsClassTeacherOfAsync(_me.SchoolId, _me.StaffId, className, sectionName, ct))
            throw new ForbiddenException(
                $"You are not the class teacher of {className}-{sectionName}, so you cannot take its attendance.");
    }

    /* ---- marks ---- */
    public async Task<IReadOnlyList<ExamDto>> GetExamsAsync(CancellationToken ct = default)
    {
        var exams = await _exams.GetAllWithPapersAsync(_me.SchoolId, ct);
        return exams.Select(ToExam).ToList();
    }
    public async Task<IReadOnlyList<MarkRowDto>> GetMarksAsync(long examId, string className, string sectionName, string subject, CancellationToken ct = default)
    {
        await AssertTeachesAsync(className, sectionName, subject, ct);
        var rows = await _exams.GetMarksAsync(_me.SchoolId, examId, className, sectionName, subject, ct);
        return rows.Select(m => new MarkRowDto(m.StudentId, m.RollNo, m.StudentName ?? "", m.Marks)).ToList();
    }
    private async Task AssertTeachesAsync(string className, string sectionName, string subject, CancellationToken ct)
    {
        var mine = await MySubjectsInAsync(className, sectionName, ct);
        if (!mine.Contains(subject?.Trim() ?? "", StringComparer.OrdinalIgnoreCase))
            throw new ForbiddenException(mine.Count == 0
                ? $"You are not assigned any subject in {className}-{sectionName}."
                : $"You do not teach {subject} in {className}-{sectionName}. You are assigned: {string.Join(", ", mine)}.");
    }

    public async Task SaveMarksAsync(SaveMarksDto dto, CancellationToken ct = default)
    {
        await AssertTeachesAsync(dto.ClassName, dto.SectionName, dto.Subject ?? "", ct);
        // The subject has to be one of the exam's papers. It used to be free text straight from a
        // textbox, so a typo wrote marks under a subject no paper and no report would ever match,
        // and nothing said so — the save simply looked successful.
        var papers = await _exams.GetMarksProgressAsync(_me.SchoolId, dto.ExamId, dto.ClassName, dto.SectionName, ct);
        var paper = papers.FirstOrDefault(p => string.Equals(p.Subject, dto.Subject?.Trim(), StringComparison.OrdinalIgnoreCase));
        if (paper is null)
            throw new ValidationException(papers.Count == 0
                ? "This exam has no papers scheduled for that class yet."
                : $"“{dto.Subject}” is not a paper in this exam. Choose one of: {string.Join(", ", papers.Select(p => p.Subject))}.");

        // Full marks come from the paper, not the caller: the grade shown to a student has to
        // agree with what the exam was actually set out of.
        var applied = await _exams.UpsertMarksAsync(_me.SchoolId, dto.ExamId, dto.ClassName, dto.SectionName,
            paper.Subject, paper.FullMarks, dto.Entries.Select(e => (e.StudentId, e.Marks)), ct);
        if (applied < dto.Entries.Count)
            throw new ValidationException(
                $"{dto.Entries.Count - applied} of {dto.Entries.Count} entries did not match a student in {dto.ClassName}-{dto.SectionName} and were not saved.");
        await RecomputeResultsAsync(dto.ExamId, dto.ClassName, dto.SectionName, ct);
    }

    public async Task<IReadOnlyList<TeachingSectionDto>> GetTeachingSectionsAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetMyAssignmentsAsync(_me.SchoolId, _me.StaffId, ct);
        return rows
            .GroupBy(a => (a.ClassName, a.SectionName))
            .Select(g => new TeachingSectionDto(
                g.Key.ClassName, g.Key.SectionName, g.First().StudentCount,
                g.Select(a => a.Subject).Distinct().OrderBy(x => x).ToList()))
            .ToList();
    }

    /// <summary>
    /// The subjects this teacher is assigned in one section. Empty means they teach nothing
    /// there — being its class teacher is not enough, since marks belong to the subject teacher.
    /// </summary>
    private async Task<IReadOnlyList<string>> MySubjectsInAsync(string className, string sectionName, CancellationToken ct)
    {
        var rows = await _repo.GetMyAssignmentsAsync(_me.SchoolId, _me.StaffId, ct);
        return rows
            .Where(a => string.Equals(a.ClassName, className, StringComparison.OrdinalIgnoreCase)
                     && string.Equals(a.SectionName, sectionName, StringComparison.OrdinalIgnoreCase))
            .Select(a => a.Subject)
            .Distinct()
            .ToList();
    }

    public async Task<MarksGridDto> GetMarksGridAsync(long examId, string className, string sectionName, CancellationToken ct = default)
    {
        var mine = await MySubjectsInAsync(className, sectionName, ct);
        var papers = (await _exams.GetMarksProgressAsync(_me.SchoolId, examId, className, sectionName, ct))
            // Only the papers for subjects this teacher actually holds in this section. The grid
            // used to list every paper of the exam, which let anyone mark anyone's subject.
            .Where(p => mine.Contains(p.Subject, StringComparer.OrdinalIgnoreCase))
            .ToList();
        var rows = await _exams.GetSectionMarksAsync(_me.SchoolId, examId, className, sectionName, ct);

        var students = rows
            .GroupBy(r => r.StudentId)
            .Select(g =>
            {
                var first = g.First();
                // Marks recorded under a subject the exam no longer has a paper for are left out:
                // the grid has no column to show them in, and echoing them back would invite a
                // save that writes them again.
                var marks = g
                    .Where(m => m.Subject.Length > 0 && papers.Any(p => p.Subject == m.Subject))
                    .ToDictionary(m => m.Subject, m => m.Marks);
                return new MarksGridStudentDto(first.StudentId, first.RollNo, first.StudentName ?? "", marks);
            })
            .ToList();

        return new MarksGridDto(
            papers.Select(p => new MarksGridSubjectDto(p.Subject, p.FullMarks, p.ExamDate)).ToList(),
            students);
    }

    /* ---- class teacher's review of the whole section ---- */
    //
    // Marks entry stays with the subject teacher, but somebody has to look at the section as a
    // whole before results go out, and that is the class teacher. So this is read-only and
    // deliberately wider than the entry grid: every paper of the exam, whoever owns it.

    public async Task<IReadOnlyList<MyClassSectionDto>> GetMyClassSectionsAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetMyClassesAsync(_me.SchoolId, _me.StaffId, ct);
        return rows.Select(r => new MyClassSectionDto(r.ClassName, r.SectionName, r.StudentCount)).ToList();
    }

    public async Task<ClassResultDto> GetClassResultAsync(long examId, string className, string sectionName, CancellationToken ct = default)
    {
        if (!await _repo.IsClassTeacherOfAsync(_me.SchoolId, _me.StaffId, className, sectionName, ct))
            throw new ForbiddenException(
                $"You are not the class teacher of {className}-{sectionName}, so you cannot review its results. " +
                "A class teacher sees every subject of their own section only.");

        var exam = await _exams.GetAsync(_me.SchoolId, examId, ct)
            ?? throw new NotFoundException("Exam not found.");

        var papers = await _exams.GetMarksProgressAsync(_me.SchoolId, examId, className, sectionName, ct);
        var rows = await _exams.GetSectionMarksAsync(_me.SchoolId, examId, className, sectionName, ct);
        var owners = await _repo.GetSectionSubjectTeachersAsync(_me.SchoolId, className, sectionName, ct);

        var subjects = papers
            .Select(p => new ClassResultSubjectDto(p.Subject, p.FullMarks, p.Entered, p.Total,
                owners.FirstOrDefault(o => string.Equals(o.Subject, p.Subject, StringComparison.OrdinalIgnoreCase))?.TeacherName))
            .ToList();

        var fullTotal = subjects.Sum(p => (decimal)p.FullMarks);

        // Totals, percentage and grade come from exam_result, not from adding the marks up here:
        // the sheet has to show the figures actually on file, the ones an approval signs off.
        // Recomputed first so a paper added or removed since the last save is reflected.
        var scale = await _results.GetGradeScaleAsync(_me.SchoolId, ct);
        await _results.RecomputeSectionAsync(_me.SchoolId, examId, className, sectionName, scale, ct);
        var stored = await _results.GetSectionResultsAsync(_me.SchoolId, examId, className, sectionName, ct);

        var students = rows
            .GroupBy(r => r.StudentId)
            .Select(g =>
            {
                var first = g.First();
                var marks = g
                    .Where(m => m.Subject.Length > 0 && subjects.Any(p => string.Equals(p.Subject, m.Subject, StringComparison.OrdinalIgnoreCase)))
                    .ToDictionary(m => m.Subject, m => m.Marks);

                var result = stored.FirstOrDefault(x => x.StudentId == first.StudentId);
                var missing = Math.Max(0, subjects.Count - (result?.SubjectsEntered ?? 0));

                return new ClassResultStudentDto(first.StudentId, first.RollNo, first.StudentName ?? "",
                    marks,
                    result?.Obtained ?? 0m, result?.FullMarks ?? fullTotal,
                    result?.Percent ?? 0m, result?.Grade ?? "—",
                    missing, result?.IsComplete ?? false);
            })
            .OrderBy(s => s.RollNo is null ? 1 : 0)
            .ThenBy(s => s.RollNo, StringComparer.OrdinalIgnoreCase)
            .ThenBy(s => s.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var approval = await _results.GetApprovalAsync(_me.SchoolId, examId, className, sectionName, ct);

        // Effective for the badge (an unpinned exam reads 'auto' in the column), but the stored
        // value for the publish gate: only an admin pinning result_published counts as published.
        return new ClassResultDto(
            exam.Id, exam.Name, ExamStatus.Effective(exam),
            string.Equals(exam.Status, "result_published", StringComparison.OrdinalIgnoreCase),
            className, sectionName, subjects, students,
            students.Sum(s => s.Missing),
            approval.Status, approval.ApprovedByName, approval.ApprovedAt, approval.Remarks,
            // Nothing to approve when there are no papers or no students, and a half-marked sheet
            // is not a result — it is a work in progress.
            subjects.Count > 0 && students.Count > 0 && students.All(s => s.IsComplete));
    }

    public async Task ApproveResultAsync(ApproveResultDto dto, CancellationToken ct = default)
    {
        if (!await _repo.IsClassTeacherOfAsync(_me.SchoolId, _me.StaffId, dto.ClassName, dto.SectionName, ct))
            throw new ForbiddenException(
                $"You are not the class teacher of {dto.ClassName}-{dto.SectionName}, so you cannot approve its results.");

        _ = await _exams.GetAsync(_me.SchoolId, dto.ExamId, ct)
            ?? throw new NotFoundException("Exam not found.");

        if (!dto.Approve)
        {
            await _results.SetApprovalAsync(_me.SchoolId, dto.ExamId, dto.ClassName, dto.SectionName,
                "pending", null, dto.Remarks, ct);
            return;
        }

        // Recompute before checking, so approval is judged against the marks as they stand rather
        // than a stale row.
        var scale = await _results.GetGradeScaleAsync(_me.SchoolId, ct);
        await _results.RecomputeSectionAsync(_me.SchoolId, dto.ExamId, dto.ClassName, dto.SectionName, scale, ct);
        var stored = await _results.GetSectionResultsAsync(_me.SchoolId, dto.ExamId, dto.ClassName, dto.SectionName, ct);

        if (stored.Count == 0)
            throw new ValidationException($"There are no students in {dto.ClassName}-{dto.SectionName} to approve.");
        var incomplete = stored.Count(r => !r.IsComplete);
        if (incomplete > 0)
            throw new ValidationException(
                $"{incomplete} student(s) still have marks missing. Every paper must be entered before the sheet can be approved.");

        await _results.SetApprovalAsync(_me.SchoolId, dto.ExamId, dto.ClassName, dto.SectionName,
            "approved", _me.StaffId, dto.Remarks, ct);
    }

    public async Task<int> SaveMarksGridAsync(SaveMarksGridDto dto, CancellationToken ct = default)
    {
        var mine = await MySubjectsInAsync(dto.ClassName, dto.SectionName, ct);
        if (mine.Count == 0)
            throw new ForbiddenException(
                $"You are not assigned any subject in {dto.ClassName}-{dto.SectionName}.");

        var all = await _exams.GetMarksProgressAsync(_me.SchoolId, dto.ExamId, dto.ClassName, dto.SectionName, ct);
        if (all.Count == 0) throw new ValidationException("This exam has no papers scheduled for that class yet.");

        // A subject that exists on the exam but belongs to another teacher is refused outright,
        // not silently skipped — a save that reports success while dropping marks is worse.
        foreach (var subject in dto.Entries.Select(e => e.Subject?.Trim() ?? "").Distinct())
            if (!mine.Contains(subject, StringComparer.OrdinalIgnoreCase))
                throw new ForbiddenException(
                    $"You do not teach {subject} in {dto.ClassName}-{dto.SectionName}. " +
                    $"You are assigned: {string.Join(", ", mine)}.");

        var papers = all.Where(p => mine.Contains(p.Subject, StringComparer.OrdinalIgnoreCase)).ToList();

        // One write per subject, so each carries that paper's own full marks.
        var written = 0;
        foreach (var group in dto.Entries.GroupBy(e => e.Subject?.Trim() ?? ""))
        {
            var paper = papers.FirstOrDefault(p => string.Equals(p.Subject, group.Key, StringComparison.OrdinalIgnoreCase))
                        ?? throw new ValidationException(
                            $"\u201C{group.Key}\u201D is not a paper in this exam. Choose one of: {string.Join(", ", papers.Select(p => p.Subject))}.");

            var entries = group.Select(e => (e.StudentId, e.Marks)).ToList();
            var applied = await _exams.UpsertMarksAsync(_me.SchoolId, dto.ExamId, dto.ClassName, dto.SectionName,
                paper.Subject, paper.FullMarks, entries, ct);
            if (applied < entries.Count)
                throw new ValidationException(
                    $"{entries.Count - applied} entry(ies) for {paper.Subject} did not match a student in {dto.ClassName}-{dto.SectionName} and were not saved.");
            written += applied;
        }
        await RecomputeResultsAsync(dto.ExamId, dto.ClassName, dto.SectionName, ct);
        return written;
    }

    public async Task<IReadOnlyList<MarksProgressDto>> GetMarksProgressAsync(long examId, string className, string sectionName, CancellationToken ct = default)
    {
        var mine = await MySubjectsInAsync(className, sectionName, ct);
        var rows = await _exams.GetMarksProgressAsync(_me.SchoolId, examId, className, sectionName, ct);
        return rows
            .Where(r => mine.Contains(r.Subject, StringComparer.OrdinalIgnoreCase))
            .Select(r => new MarksProgressDto(r.Subject, r.FullMarks, r.ExamDate, r.Entered, r.Total))
            .ToList();
    }

    /* ---- timetable ---- */
    public async Task<TeacherTimetableDto> GetTimetableAsync(CancellationToken ct = default)
    {
        var slots = await _timetable.GetByTeacherAsync(_me.SchoolId, _me.StaffId, ct);

        // The columns come from the school's own periods. Period numbers count breaks too, so a
        // fixed 1..6 grid would label everything after the break wrongly and lose the last period.
        var periods = await _timetable.GetPeriodsAsync(_me.SchoolId, ct);
        if (periods.Count == 0)
        {
            await _timetable.SeedDefaultPeriodsAsync(_me.SchoolId, ct);
            periods = await _timetable.GetPeriodsAsync(_me.SchoolId, ct);
        }

        return new TeacherTimetableDto(
            periods.Select((p, i) => new TimetablePeriodDto(
                i + 1, p.Name, $"{p.StartTime:hh\\:mm}–{p.EndTime:hh\\:mm}", p.IsBreak)).ToList(),
            slots.Select(s => new TimetableSlotDto(s.DayOfWeek, s.PeriodNo, s.TimeLabel,
                $"{s.ClassLabel}-{s.SectionLabel} · {s.Subject}", s.Room)).ToList());
    }

    private static ExamDto ToExam(Exam e) => new(
        e.Id, e.Name, e.Type, e.StartDate, e.EndDate, e.Classes,
        ExamStatus.Effective(e), ExamStatus.IsManual(e), ExamStatus.FromDates(e), e.Papers.Count,
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
        s.Phone, s.Email, s.Qualification, s.JoiningDate);

    private static HomeworkDto ToHomework(TeacherHomework h) => new(
        h.Id, h.Title, h.Subject, h.ClassLabel, h.AssignedDate, h.DueDate,
        h.SubmittedCount, h.TotalCount, h.Status);
}
