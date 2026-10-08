using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services.Admin;

public class AdminDashboardService : IAdminDashboardService
{
    private readonly IStudentRepository _students;
    private readonly ITeacherRepository _teachers;
    private readonly IClassRepository _classes;
    private readonly INoticeRepository _notices;
    private readonly ISchoolRepository _schools;
    private readonly IFeeRepository _fees;
    private readonly IAttendanceRepository _attendance;
    private readonly ICurrentSchool _school;
    private readonly ISubscriptionGuard _entitlements;

    /// <summary>How many marked days the dashboard attendance chart plots.</summary>
    private const int TrendDays = 30;

    public AdminDashboardService(IStudentRepository students, ITeacherRepository teachers,
        IClassRepository classes, INoticeRepository notices, ISchoolRepository schools,
        IFeeRepository fees, IAttendanceRepository attendance, ICurrentSchool school,
        ISubscriptionGuard entitlements)
    {
        _students = students;
        _teachers = teachers;
        _classes = classes;
        _notices = notices;
        _schools = schools;
        _fees = fees;
        _attendance = attendance;
        _school = school;
        _entitlements = entitlements;
    }

    public async Task<AdminDashboardDto> GetAsync(CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var school = await _schools.GetByIdAsync(sid, ct)
            ?? throw new NotFoundException($"School {sid} no longer exists.");
        var academicYear = await _schools.GetCurrentAcademicYearAsync(sid, ct);

        var totalStudents = await _students.CountAsync(sid, ct);
        var totalTeachers = await _teachers.CountAsync(sid, null, ct);
        var onLeave = await _teachers.CountAsync(sid, "on_leave", ct);
        var classes = await _classes.CountAsync(sid, ct);
        var sections = (await _classes.GetAllWithSectionsAsync(sid, ct)).Sum(c => c.Sections.Count);
        var feesDue = await _students.TotalFeesDueAsync(sid, ct);

        // Invoice totals: one read, summed here rather than four aggregate round-trips.
        var invoices = await _fees.GetInvoicesAsync(sid, null, ct);
        var billed = invoices.Sum(i => i.Amount);
        var collected = invoices.Sum(i => i.Paid);
        var overdue = invoices.Where(i => i.Status == "overdue").Sum(i => i.Amount - i.Paid);
        var unpaid = invoices.Count(i => i.Status is "unpaid" or "partial" or "overdue");

        var today = DateTime.UtcNow.Date;
        var rates = await _attendance.GetDailyRatesAsync(sid, TrendDays, ct);
        var trend = rates
            .Select(r => new AttendancePointDto(r.Date,
                r.Total == 0 ? 0 : Math.Round(r.Present * 100.0 / r.Total, 1), r.Present, r.Total))
            .ToList();
        // Null (not zero) when today is unmarked, so the tile can say "not marked yet".
        double? attendanceToday = trend.LastOrDefault(p => p.Date.Date == today)?.Percent;

        var recent = (await _students.RecentAsync(sid, 5, ct))
            .Select(s => new RecentAdmissionDto($"{s.FirstName} {s.LastName}".Trim(), s.ClassName, s.SectionName, s.AdmissionDate))
            .ToList();
        var notices = (await _notices.GetAllAsync(sid, 3, ct))
            .Select(n => new NoticeDto(n.Id, n.Title, n.Body, n.Audience, n.PublishDate, n.CreatedBy, n.CreatedByName)).ToList();

        var subscription = await _entitlements.GetStatusAsync(sid, ct);

        return new AdminDashboardDto(school.Name, academicYear, totalStudents, totalTeachers, onLeave,
            classes, sections, feesDue, billed, collected, overdue, unpaid,
            attendanceToday, trend, recent, notices, subscription);
    }
}
