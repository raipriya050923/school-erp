using System.Globalization;
using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Student;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.StudentPortal;

public class StudentPortalService : IStudentPortalService
{
    private readonly IStudentPortalRepository _repo;
    private readonly ICurrentStudent _me;

    public StudentPortalService(IStudentPortalRepository repo, ICurrentStudent me)
    {
        _repo = repo;
        _me = me;
    }

    private async Task<Student> ProfileOrThrow(CancellationToken ct)
        => await _repo.GetProfileAsync(_me.SchoolId, _me.StudentId, ct)
           ?? throw new NotFoundException("Student not found.");

    public async Task<StudentProfileDto?> GetProfileAsync(CancellationToken ct = default)
    {
        var s = await _repo.GetProfileAsync(_me.SchoolId, _me.StudentId, ct);
        return s is null ? null : new StudentProfileDto(s.Id, s.AdmissionNo, $"{s.FirstName} {s.LastName}".Trim(), s.ClassName, s.SectionName, s.RollNo);
    }

    public async Task<StudentAttendanceDto> GetAttendanceAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetAttendanceAsync(_me.SchoolId, _me.StudentId, ct);
        var work = rows.Where(r => r.Status != "holiday").ToList();
        int present = work.Count(r => r.Status == "present");
        int late = work.Count(r => r.Status == "late");
        int absent = work.Count(r => r.Status == "absent");
        int totalDays = work.Count;
        int overall = totalDays == 0 ? 0 : (int)Math.Round((present + late) / (double)totalDays * 100);

        var months = work
            .GroupBy(r => new DateTime(r.AttendanceDate.Year, r.AttendanceDate.Month, 1))
            .OrderBy(g => g.Key)
            .Select(g =>
            {
                var p = g.Count(x => x.Status == "present");
                var l = g.Count(x => x.Status == "late");
                var a = g.Count(x => x.Status == "absent");
                var pct = g.Count() == 0 ? 0 : (int)Math.Round((p + l) / (double)g.Count() * 100);
                return new AttendanceMonthDto(g.Key.ToString("MMMM yyyy", CultureInfo.InvariantCulture), p, a, l, pct);
            }).ToList();

        var recent = rows.OrderByDescending(r => r.AttendanceDate).Take(8)
            .Select(r => new AttendanceRecentDto(
                r.AttendanceDate.ToString("yyyy-MM-dd"),
                r.AttendanceDate.DayOfWeek.ToString(),
                Cap(r.Status))).ToList();

        return new StudentAttendanceDto(overall, present, totalDays, months, recent);
    }

    public async Task<IReadOnlyList<StudentTimetableSlotDto>> GetTimetableAsync(CancellationToken ct = default)
    {
        var me = await ProfileOrThrow(ct);
        var slots = await _repo.GetTimetableAsync(_me.SchoolId, me.ClassName ?? "", me.SectionName ?? "", ct);
        return slots.Select(s => new StudentTimetableSlotDto(s.DayOfWeek, s.PeriodNo, s.TimeLabel, s.Subject, s.Room)).ToList();
    }

    public async Task<IReadOnlyList<StudentHomeworkDto>> GetHomeworkAsync(CancellationToken ct = default)
    {
        var me = await ProfileOrThrow(ct);
        var label = $"{me.ClassName}-{me.SectionName}";
        var rows = await _repo.GetHomeworkAsync(_me.SchoolId, me.ClassName ?? "", label, ct);
        return rows.Select(h => new StudentHomeworkDto(h.Title, h.Subject, h.DueDate, StudentHwStatus(h))).ToList();
    }

    public async Task<StudentExamsDto> GetExamsAsync(CancellationToken ct = default)
    {
        var me = await ProfileOrThrow(ct);
        var exam = await _repo.GetPublishedExamAsync(_me.SchoolId, ct);
        var results = new List<StudentResultDto>();
        decimal total = 0, fullTotal = 0;
        string? examName = exam?.Name;
        if (exam is not null)
        {
            var marks = await _repo.GetMarksAsync(_me.SchoolId, _me.StudentId, exam.Id, ct);
            foreach (var m in marks)
            {
                results.Add(new StudentResultDto(m.Subject, m.FullMarks, m.Marks, Grade(m.Marks, m.FullMarks)));
                total += m.Marks ?? 0;
                fullTotal += m.FullMarks;
            }
        }
        var pct = fullTotal == 0 ? 0 : (int)Math.Round(total / fullTotal * 100);

        var papers = await _repo.GetUpcomingPapersAsync(_me.SchoolId, me.ClassName ?? "", ct);
        var upcoming = papers.Select(p => new UpcomingPaperDto(p.ExamDate, p.Subject, p.TimeLabel, p.Room)).ToList();

        return new StudentExamsDto(examName, total, fullTotal, pct, Grade(total, fullTotal == 0 ? 1 : fullTotal), results, upcoming);
    }

    public async Task<IReadOnlyList<StudentFeeDto>> GetFeesAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetFeesAsync(_me.SchoolId, _me.StudentId, ct);
        return rows.Select(i => new StudentFeeDto(i.InvoiceNo, i.Month, i.Amount, i.Paid, i.Amount - i.Paid, i.DueDate, i.Status)).ToList();
    }

    public async Task<IReadOnlyList<StudentNoticeDto>> GetNoticesAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetNoticesAsync(_me.SchoolId, ct);
        return rows.Select(n => new StudentNoticeDto(n.Id, n.Title, n.Body, n.Audience, n.PublishDate)).ToList();
    }

    public async Task<StudentDashboardDto> GetDashboardAsync(CancellationToken ct = default)
    {
        var me = await ProfileOrThrow(ct);
        var att = await GetAttendanceAsync(ct);
        var hw = await GetHomeworkAsync(ct);
        var pending = hw.Where(h => h.Status == "Pending").ToList();
        var papers = await _repo.GetUpcomingPapersAsync(_me.SchoolId, me.ClassName ?? "", ct);
        var next = papers.OrderBy(p => p.ExamDate).FirstOrDefault();
        var fees = await _repo.GetFeesAsync(_me.SchoolId, _me.StudentId, ct);
        var feeDue = fees.Sum(f => f.Amount - f.Paid);

        return new StudentDashboardDto(
            $"{me.FirstName} {me.LastName}".Trim(), me.ClassName, me.SectionName, me.RollNo,
            att.OverallPercent, att.PresentDays, att.TotalDays,
            pending.Count, next?.Subject, next?.ExamDate, feeDue,
            pending.Take(3).ToList());
    }

    private static string StudentHwStatus(TeacherHomework h)
        => h.DueDate.HasValue && h.DueDate.Value.Date < DateTime.UtcNow.Date ? "Closed" : "Pending";

    private static string Grade(decimal? marks, decimal full)
    {
        if (marks is null || full == 0) return "—";
        var pct = (double)(marks.Value / full) * 100;
        return pct switch
        {
            >= 90 => "A+", >= 80 => "A", >= 70 => "B+", >= 60 => "B",
            >= 50 => "C+", >= 40 => "C", _ => "NG",
        };
    }

    private static string Cap(string s) => string.IsNullOrEmpty(s) ? s : char.ToUpper(s[0]) + s[1..];
}
