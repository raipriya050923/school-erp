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
    private readonly ICurrentSchool _school;

    public AdminDashboardService(IStudentRepository students, ITeacherRepository teachers,
        IClassRepository classes, INoticeRepository notices, ICurrentSchool school)
    {
        _students = students;
        _teachers = teachers;
        _classes = classes;
        _notices = notices;
        _school = school;
    }

    public async Task<AdminDashboardDto> GetAsync(CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var totalStudents = await _students.CountAsync(sid, ct);
        var totalTeachers = await _teachers.CountAsync(sid, null, ct);
        var onLeave = await _teachers.CountAsync(sid, "on_leave", ct);
        var classes = await _classes.CountAsync(sid, ct);
        var feesDue = await _students.TotalFeesDueAsync(sid, ct);

        var recent = (await _students.RecentAsync(sid, 5, ct))
            .Select(s => new RecentAdmissionDto($"{s.FirstName} {s.LastName}".Trim(), s.ClassName, s.SectionName, s.AdmissionDate))
            .ToList();
        var notices = (await _notices.GetAllAsync(sid, 3, ct))
            .Select(n => new NoticeDto(n.Id, n.Title, n.Body, n.Audience, n.PublishDate)).ToList();

        return new AdminDashboardDto(totalStudents, totalTeachers, onLeave, classes, feesDue, recent, notices);
    }
}
