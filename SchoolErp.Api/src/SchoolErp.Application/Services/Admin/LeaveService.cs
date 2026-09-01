using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

public class LeaveService : ILeaveService
{
    private static readonly string[] ReviewStatuses = { "approved", "rejected" };
    private readonly ILeaveRepository _repo;
    private readonly ICurrentSchool _school;
    private readonly ICurrentUser _user;
    private readonly ITeacherRepository _staff;

    public LeaveService(ILeaveRepository repo, ICurrentSchool school, ICurrentUser user,
        ITeacherRepository staff)
    {
        _repo = repo;
        _school = school;
        _user = user;
        _staff = staff;
    }

    public async Task<IReadOnlyList<LeaveTypeDto>> TypesAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetTypesAsync(_school.SchoolId, ct);
        if (rows.Count == 0)
        {
            // Schools created before leave existed have none, which would leave the apply form
            // with an empty dropdown and no way to proceed.
            await _repo.SeedDefaultTypesAsync(_school.SchoolId, ct);
            rows = await _repo.GetTypesAsync(_school.SchoolId, ct);
        }
        return rows.Select(t => new LeaveTypeDto(t.Id, t.Name, t.IsPaid, t.MaxDaysPerYear)).ToList();
    }

    public async Task<IReadOnlyList<LeaveApplicationDto>> ListAsync(string? status, CancellationToken ct = default)
        => (await _repo.GetAllAsync(_school.SchoolId, status, ct)).Select(ToDto).ToList();

    public async Task<IReadOnlyList<LeaveApplicationDto>> MineAsync(CancellationToken ct = default)
        => (await _repo.GetForApplicantAsync(_school.SchoolId, _user.UserId, ct)).Select(ToDto).ToList();

    public Task<long> ApplyAsync(ApplyLeaveDto dto, CancellationToken ct = default)
        => CreateAsync(dto, _user.UserId, approveNow: false, ct);

    /// <summary>
    /// An admin recording an absence for someone who phoned in. The row is filed against that
    /// person's own login, so it shows up in their "My Leave" list exactly as if they had applied.
    /// </summary>
    public async Task<long> ApplyForStaffAsync(ApplyLeaveForStaffDto dto, CancellationToken ct = default)
    {
        if (dto.StaffId <= 0) throw new ValidationException("Choose a staff member.");
        var member = await _staff.GetByIdAsync(_school.SchoolId, dto.StaffId, ct)
                     ?? throw new ValidationException("That staff member no longer exists at this school.");
        if (member.UserId is not { } applicantUserId)
            throw new ValidationException(
                $"{member.FirstName} {member.LastName} has no login account, so leave cannot be filed against them.");

        return await CreateAsync(dto, applicantUserId, dto.AutoApprove, ct);
    }

    public async Task<long> CreateTypeAsync(SaveLeaveTypeDto dto, CancellationToken ct = default)
    {
        var name = dto.Name?.Trim() ?? "";
        if (name.Length == 0) throw new ValidationException("Leave type name is required.");
        if (dto.MaxDaysPerYear is { } max && max < 1)
            throw new ValidationException("Leave blank for unlimited, or enter 1 day or more.");
        if (await _repo.TypeNameExistsAsync(_school.SchoolId, name, ct))
            throw new ValidationException($"A leave type named “{name}” already exists.");

        return await _repo.CreateTypeAsync(new LeaveType
        {
            SchoolId = _school.SchoolId,
            Name = name,
            IsPaid = dto.IsPaid,
            MaxDaysPerYear = dto.MaxDaysPerYear,
        }, ct);
    }

    private async Task<long> CreateAsync(ApplyLeaveDto dto, long applicantUserId, bool approveNow, CancellationToken ct)
    {
        if (dto.LeaveTypeId <= 0) throw new ValidationException("Choose a leave type.");
        if (dto.FromDate == default || dto.ToDate == default)
            throw new ValidationException("From and to dates are required.");
        if (dto.FromDate.Date > dto.ToDate.Date)
            throw new ValidationException("The from date must be on or before the to date.");
        if (string.IsNullOrWhiteSpace(dto.Reason))
            throw new ValidationException("A reason is required.");

        var types = await _repo.GetTypesAsync(_school.SchoolId, ct);
        if (types.All(t => t.Id != dto.LeaveTypeId))
            throw new ValidationException("That leave type is not available at this school.");

        // Inclusive of both ends: a single-day leave is one day, not zero.
        var days = (dto.ToDate.Date - dto.FromDate.Date).Days + 1;
        var id = await _repo.CreateAsync(new LeaveApplication
        {
            SchoolId = _school.SchoolId,
            LeaveTypeId = dto.LeaveTypeId,
            ApplicantUserId = applicantUserId,
            FromDate = dto.FromDate,
            ToDate = dto.ToDate,
            Days = days,
            Reason = dto.Reason.Trim(),
        }, ct);

        // Recorded by an admin who has already accepted it — approving here is what makes staff
        // attendance show the person as on_leave for those dates.
        if (approveNow)
            await _repo.ReviewAsync(_school.SchoolId, id, "approved", _user.UserId, "Recorded by the school office.", ct);

        return id;
    }

    public async Task ReviewAsync(long id, ReviewLeaveDto dto, CancellationToken ct = default)
    {
        if (!ReviewStatuses.Contains(dto.Status))
            throw new ValidationException("A leave request can only be approved or rejected.");
        var application = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
                          ?? throw new NotFoundException($"Leave request {id} not found.");
        if (application.Status != "pending")
            throw new ValidationException($"This request was already {application.Status}.");

        await _repo.ReviewAsync(_school.SchoolId, id, dto.Status, _user.UserId, dto.Remarks?.Trim(), ct);
    }

    private static LeaveApplicationDto ToDto(LeaveApplication a) => new(
        a.Id, a.LeaveTypeId, a.LeaveTypeName, a.ApplicantName, a.FromDate, a.ToDate, a.Days,
        a.Reason, a.Status, a.ReviewedByName, a.ReviewedAt, a.ReviewRemarks, a.CreatedAt);
}
