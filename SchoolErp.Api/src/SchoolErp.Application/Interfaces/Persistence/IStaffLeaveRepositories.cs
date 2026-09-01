using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IStaffAttendanceRepository
{
    /// <summary>
    /// One row per active staff member for the date — saved status where it exists, otherwise a
    /// default. Staff with an approved leave covering the date default to <c>on_leave</c> so the
    /// admin is not re-entering something the leave workflow already decided.
    /// </summary>
    Task<IReadOnlyList<StaffAttendance>> GetForDateAsync(long schoolId, DateTime date, CancellationToken ct = default);

    Task UpsertAsync(long schoolId, DateTime date, long markedByUserId,
        IEnumerable<(long StaffId, string Status, string? Remarks)> entries, CancellationToken ct = default);

    /// <summary>Per-status totals across a date range, for the summary tiles.</summary>
    Task<IReadOnlyList<(string Status, int Count)>> SummaryAsync(
        long schoolId, DateTime from, DateTime to, CancellationToken ct = default);
}

public interface ILeaveRepository
{
    Task<IReadOnlyList<LeaveType>> GetTypesAsync(long schoolId, CancellationToken ct = default);
    Task SeedDefaultTypesAsync(long schoolId, CancellationToken ct = default);
    Task<bool> TypeNameExistsAsync(long schoolId, string name, CancellationToken ct = default);
    Task<long> CreateTypeAsync(LeaveType type, CancellationToken ct = default);

    /// <summary>School-wide applications, newest first, optionally narrowed by status.</summary>
    Task<IReadOnlyList<LeaveApplication>> GetAllAsync(long schoolId, string? status, CancellationToken ct = default);
    /// <summary>Just this applicant's own requests — what a teacher sees.</summary>
    Task<IReadOnlyList<LeaveApplication>> GetForApplicantAsync(long schoolId, long userId, CancellationToken ct = default);
    Task<LeaveApplication?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default);
    Task<long> CreateAsync(LeaveApplication application, CancellationToken ct = default);
    Task ReviewAsync(long schoolId, long id, string status, long reviewerUserId, string? remarks, CancellationToken ct = default);
}
