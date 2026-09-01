using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services.Admin;

public class StaffAttendanceService : IStaffAttendanceService
{
    private static readonly string[] ValidStatuses = { "present", "absent", "late", "half_day", "on_leave" };
    private readonly IStaffAttendanceRepository _repo;
    private readonly ICurrentSchool _school;
    private readonly ICurrentUser _user;
    private readonly ISchoolClock _clock;

    public StaffAttendanceService(IStaffAttendanceRepository repo, ICurrentSchool school,
        ICurrentUser user, ISchoolClock clock)
    {
        _repo = repo;
        _school = school;
        _user = user;
        _clock = clock;
    }

    public async Task<IReadOnlyList<StaffAttendanceRowDto>> GetAsync(DateTime date, CancellationToken ct = default)
    {
        var rows = await _repo.GetForDateAsync(_school.SchoolId, date, ct);
        return rows.Select(r => new StaffAttendanceRowDto(
            r.StaffId, r.EmployeeCode, r.StaffName ?? "", r.Status, r.Remarks)).ToList();
    }

    public async Task SaveAsync(SaveStaffAttendanceDto dto, CancellationToken ct = default)
    {
        if (dto.Date == default) throw new ValidationException("A date is required.");
        // Judged against the school's own date, not UTC: the server is hours behind the school,
        // so a UTC comparison rejected today's attendance every evening.
        if (dto.Date.Date > await _clock.TodayAsync(ct))
            throw new ValidationException("Attendance cannot be marked for a future date.");
        if (dto.Entries.Count == 0) throw new ValidationException("Nothing to save.");

        var invalid = dto.Entries.FirstOrDefault(e => !ValidStatuses.Contains(e.Status));
        if (invalid is not null) throw new ValidationException($"'{invalid.Status}' is not a valid attendance status.");

        await _repo.UpsertAsync(_school.SchoolId, dto.Date, _user.UserId,
            dto.Entries.Select(e => (e.StaffId, e.Status, e.Remarks)), ct);
    }

    public async Task<StaffAttendanceSummaryDto> SummaryAsync(DateTime from, DateTime to, CancellationToken ct = default)
    {
        if (from > to) (from, to) = (to, from);
        var rows = await _repo.SummaryAsync(_school.SchoolId, from, to, ct);
        int Count(string s) => rows.FirstOrDefault(r => r.Status == s).Count;
        return new StaffAttendanceSummaryDto(
            Count("present"), Count("absent"), Count("late"), Count("half_day"), Count("on_leave"));
    }
}
