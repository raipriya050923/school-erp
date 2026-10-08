using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

public class StudentService : IStudentService
{
    private static readonly string[] Statuses = { "active", "inactive", "transferred", "graduated", "dropped" };
    private readonly IStudentRepository _repo;
    private readonly ICurrentSchool _school;
    private readonly IAccountProvisioner _accounts;
    private readonly IGeographyService _geography;
    private readonly INotificationCenter _bell;
    private readonly ISubscriptionGuard _entitlements;

    public StudentService(IStudentRepository repo, ICurrentSchool school, IAccountProvisioner accounts,
        INotificationCenter bell, IGeographyService geography, ISubscriptionGuard entitlements)
    {
        _repo = repo;
        _school = school;
        _accounts = accounts;
        _bell = bell;
        _geography = geography;
        _entitlements = entitlements;
    }

    /// <summary>
    /// Resolves the state/city ids against the master and mirrors the names into the
    /// text columns, so the two representations cannot drift apart.
    /// </summary>
    private async Task ApplyPlaceAsync(Student s, SaveStudentDto dto, CancellationToken ct)
    {
        var place = await _geography.ResolveAsync(null, dto.StateId, dto.CityId, ct);
        s.StateId = place.StateId;
        s.CityId = place.CityId;
        s.State = place.StateName ?? dto.State;
        s.City = place.CityName ?? dto.City;
    }

    /// <summary>
    /// Largest page a caller may ask for, so a crafted page size cannot pull the whole roster in
    /// one request. Set at the cap the unpaged query used to carry, because the screens that
    /// fill a student picker still ask for everything in one go.
    /// </summary>
    private const int MaxPageSize = 500;

    public async Task<PagedDto<StudentListItemDto>> ListAsync(
        string? search, string? className, DateTime? admittedFrom, DateTime? admittedTo,
        int page, int pageSize, CancellationToken ct = default)
    {
        pageSize = Math.Clamp(pageSize <= 0 ? 25 : pageSize, 5, MaxPageSize);
        page = Math.Max(1, page);
        var (rows, total) = await _repo.GetPageAsync(
            _school.SchoolId, search, className, admittedFrom, admittedTo, (page - 1) * pageSize, pageSize, ct);

        // A caller can be stranded past the end — page 7 of a list that a filter has just cut to
        // three. Serving the last page instead keeps the table from going blank with no way back.
        var totalPages = total == 0 ? 1 : (int)Math.Ceiling(total / (double)pageSize);
        if (page > totalPages)
        {
            page = totalPages;
            (rows, total) = await _repo.GetPageAsync(
                _school.SchoolId, search, className, admittedFrom, admittedTo, (page - 1) * pageSize, pageSize, ct);
        }

        var items = rows.Select(s => new StudentListItemDto(
            s.Id, s.AdmissionNo, $"{s.FirstName} {s.LastName}".Trim(), s.ClassName, s.SectionName,
            s.RollNo, s.GuardianName, s.GuardianPhone, s.FeeDue, s.Status, s.AdmissionDate)).ToList();
        return new PagedDto<StudentListItemDto>(items, page, pageSize, total, totalPages);
    }

    public async Task<StudentDetailDto?> GetAsync(long id, CancellationToken ct = default)
    {
        var s = await _repo.GetByIdAsync(_school.SchoolId, id, ct);
        if (s is null) return null;
        return new StudentDetailDto(s.Id, s.AdmissionNo, $"{s.FirstName} {s.LastName}".Trim(),
            s.FirstName, s.LastName, s.ClassName, s.SectionName, s.RollNo, s.Gender, s.Dob,
            s.BloodGroup, s.Email, s.Phone, s.GuardianName, s.GuardianPhone, s.Address, s.City,
            s.State, s.Pincode, s.TcNo, s.PreviousSchool, s.AdmissionDate, s.FeeDue, s.Status,
            s.StateId, s.CityId);
    }

    public async Task<CreateStudentResultDto> CreateAsync(SaveStudentDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        // Checked before anything is written: an admission number and a login are
        // issued below, and handing those out only to fail afterwards would leave
        // the sequence advanced and an orphaned account behind.
        await _entitlements.EnsureCanAdmitStudentAsync(_school.SchoolId, ct);
        var s = Map(new Student { SchoolId = _school.SchoolId }, dto);
        await ApplyPlaceAsync(s, dto, ct);
        s.AdmissionNo = await _repo.NextAdmissionNoAsync(_school.SchoolId, ct);
        // Roll numbers run per class/section; the client only previews one, the server decides it.
        if (string.IsNullOrWhiteSpace(s.RollNo))
            s.RollNo = await _repo.NextRollNoAsync(_school.SchoolId, s.ClassName, s.SectionName, ct);
        s.AdmissionDate = DateTime.UtcNow;
        s.Status = "active";
        var id = await _repo.CreateAsync(s, ct);

        var fullName = $"{s.FirstName} {s.LastName}".Trim();
        var credentials = await _accounts.ProvisionAsync(
            _school.SchoolId, "student", CredentialGenerator.UsernameStem(s.FirstName, s.LastName),
            fullName, s.Email, s.Phone, ct);
        // The student portal resolves student_id from students.user_id at login.
        await _repo.SetUserIdAsync(_school.SchoolId, id, credentials.UserId, ct);

        await _bell.NotifyRoleAsync(_school.SchoolId, "school_admin",
            "New admission", $"{fullName} joined {s.ClassName}-{s.SectionName} (roll {s.RollNo}).",
            "admission", "students", id, ct);

        return new CreateStudentResultDto(id, s.AdmissionNo, s.RollNo, credentials);
    }

    public Task<string> NextRollNoAsync(string? className, string? sectionName, CancellationToken ct = default)
        => _repo.NextRollNoAsync(_school.SchoolId, className, sectionName, ct);

    public async Task UpdateAsync(long id, SaveStudentDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        var s = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
                ?? throw new NotFoundException($"Student {id} not found.");
        Map(s, dto);
        await ApplyPlaceAsync(s, dto, ct);
        await _repo.UpdateAsync(s, ct);
    }

    public async Task SetStatusAsync(long id, string status, CancellationToken ct = default)
    {
        if (!Statuses.Contains(status)) throw new ValidationException($"Invalid status '{status}'.");
        _ = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
            ?? throw new NotFoundException($"Student {id} not found.");
        await _repo.SetStatusAsync(_school.SchoolId, id, status, ct);
    }

    private static void Validate(SaveStudentDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.FirstName) || string.IsNullOrWhiteSpace(dto.LastName))
            throw new ValidationException("First and last name are required.");
        if (string.IsNullOrWhiteSpace(dto.GuardianName) || string.IsNullOrWhiteSpace(dto.GuardianPhone))
            throw new ValidationException("Guardian name and phone are required.");
    }

    private static Student Map(Student s, SaveStudentDto d)
    {
        s.FirstName = d.FirstName.Trim();
        s.LastName = d.LastName.Trim();
        s.ClassName = d.ClassName;
        s.SectionName = d.SectionName;
        s.RollNo = d.RollNo;
        s.Gender = d.Gender;
        s.Dob = d.Dob;
        s.BloodGroup = d.BloodGroup;
        s.Email = d.Email;
        s.GuardianName = d.GuardianName?.Trim();
        s.GuardianPhone = d.GuardianPhone?.Trim();
        s.Address = d.Address;
        s.City = d.City;
        s.State = d.State;
        s.Pincode = d.Pincode;
        s.PreviousSchool = d.PreviousSchool;
        s.TcNo = string.IsNullOrWhiteSpace(d.TcNo) ? null : d.TcNo.Trim();
        return s;
    }
}
