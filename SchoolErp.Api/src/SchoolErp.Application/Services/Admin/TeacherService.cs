using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

public class TeacherService : ITeacherService
{
    private static readonly string[] Statuses = { "active", "on_leave", "resigned", "terminated", "inactive" };
    private readonly ITeacherRepository _repo;
    private readonly ICurrentSchool _school;
    private readonly IAccountProvisioner _accounts;
    private readonly IGeographyService _geography;

    public TeacherService(ITeacherRepository repo, ICurrentSchool school, IAccountProvisioner accounts,
        IGeographyService geography)
    {
        _geography = geography;
        _repo = repo;
        _school = school;
        _accounts = accounts;
    }

    /// <summary>
    /// Resolves the state/city ids against the master and mirrors the names into the
    /// text columns, so the two representations cannot drift apart.
    /// </summary>
    private async Task ApplyPlaceAsync(StaffMember t, SaveTeacherDto dto, CancellationToken ct)
    {
        var place = await _geography.ResolveAsync(null, dto.StateId, dto.CityId, ct);
        t.StateId = place.StateId;
        t.CityId = place.CityId;
        t.State = place.StateName ?? dto.State;
        t.City = place.CityName ?? dto.City;
    }

    public async Task<IReadOnlyList<TeacherListItemDto>> ListAsync(string? search, CancellationToken ct = default)
    {
        var rows = await _repo.GetAllAsync(_school.SchoolId, search, ct);
        var classTeacherOf = await _repo.GetClassTeacherSectionsAsync(_school.SchoolId, ct);
        return rows.Select(t => new TeacherListItemDto(
            t.Id, t.EmployeeCode, $"{t.FirstName} {t.LastName}".Trim(), t.Specialization,
            t.Phone, t.Email, t.Status, t.JoiningDate,
            classTeacherOf.TryGetValue(t.Id, out var label) ? label : null)).ToList();
    }

    public async Task<TeacherDetailDto?> GetAsync(long id, CancellationToken ct = default)
    {
        var t = await _repo.GetByIdAsync(_school.SchoolId, id, ct);
        if (t is null) return null;
        var qualifications = await _repo.GetQualificationsAsync(_school.SchoolId, id, ct);
        return new TeacherDetailDto(t.Id, t.EmployeeCode, $"{t.FirstName} {t.LastName}".Trim(),
            t.FirstName, t.LastName, t.Specialization, t.Phone, t.Email,
            t.Qualification, t.Gender, t.Dob, t.Address, t.City, t.State, t.Pincode, t.JoiningDate, t.Status,
            t.StateId, t.CityId,
            qualifications.Select(q => new QualificationDto(q.Name, q.Institution, q.CompletionYear)).ToList());
    }

    public async Task<CreateTeacherResultDto> CreateAsync(SaveTeacherDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        var t = Map(new StaffMember { SchoolId = _school.SchoolId, StaffType = "teacher" }, dto);
        await ApplyPlaceAsync(t, dto, ct);
        t.EmployeeCode = await _repo.NextEmployeeCodeAsync(_school.SchoolId, ct);
        t.JoiningDate = DateTime.UtcNow;
        t.Status = "active";
        var id = await _repo.CreateAsync(t, ct);

        var fullName = $"{t.FirstName} {t.LastName}".Trim();
        var credentials = await _accounts.ProvisionAsync(
            _school.SchoolId, "teacher", CredentialGenerator.UsernameStem(t.FirstName, t.LastName),
            fullName, t.Email, t.Phone, ct);
        // The teacher portal resolves staff_id from staff.user_id at login, so this link is what
        // actually lets the new account reach its own classes.
        await _repo.SetUserIdAsync(_school.SchoolId, id, credentials.UserId, ct);
        await _repo.ReplaceQualificationsAsync(_school.SchoolId, id, Qualifications(dto), ct);

        return new CreateTeacherResultDto(id, t.EmployeeCode, credentials);
    }

    public async Task UpdateAsync(long id, SaveTeacherDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        var t = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
                ?? throw new NotFoundException($"Teacher {id} not found.");
        Map(t, dto);
        await ApplyPlaceAsync(t, dto, ct);
        await _repo.UpdateAsync(t, ct);
        await _repo.ReplaceQualificationsAsync(_school.SchoolId, id, Qualifications(dto), ct);
    }

    public async Task SetStatusAsync(long id, string status, CancellationToken ct = default)
    {
        if (!Statuses.Contains(status)) throw new ValidationException($"Invalid status '{status}'.");
        _ = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
            ?? throw new NotFoundException($"Teacher {id} not found.");
        await _repo.SetStatusAsync(_school.SchoolId, id, status, ct);
    }

    /// <summary>
    /// The qualification list, falling back to the legacy single field so an older client that
    /// still posts `qualification` alone keeps working.
    /// </summary>
    private static IReadOnlyList<StaffQualification> Qualifications(SaveTeacherDto d)
    {
        var list = d.Qualifications?
                       .Where(q => !string.IsNullOrWhiteSpace(q.Name))
                       .Select(q => new StaffQualification
                       {
                           Name = q.Name.Trim(),
                           Institution = string.IsNullOrWhiteSpace(q.Institution) ? null : q.Institution.Trim(),
                           CompletionYear = ValidYear(q.CompletionYear),
                       })
                       // De-duplicated here, not only in the repository, so the summary column
                       // written from this list matches the rows that actually get stored.
                       .DistinctBy(q => (q.Name.ToLowerInvariant(), q.Institution?.ToLowerInvariant()))
                       .ToList()
                   ?? new List<StaffQualification>();
        if (list.Count == 0 && !string.IsNullOrWhiteSpace(d.Qualification))
            list.Add(new StaffQualification { Name = d.Qualification.Trim() });
        return list;
    }

    /// <summary>
    /// A year outside living memory is a typo, not a qualification. Rejecting rather than
    /// silently dropping it: an admin who typed 2205 needs to know it was not recorded.
    /// </summary>
    private static int? ValidYear(int? year)
    {
        if (year is null) return null;
        var thisYear = DateTime.UtcNow.Year;
        if (year < 1950 || year > thisYear)
            throw new ValidationException($"Completion year must be between 1950 and {thisYear}.");
        return year;
    }

    /// <summary>"M.A. English (Delhi University, 2015)" — what the single summary column shows.</summary>
    private static string Summarise(StaffQualification q)
    {
        var detail = string.Join(", ", new[] { q.Institution, q.CompletionYear?.ToString() }
            .Where(x => !string.IsNullOrWhiteSpace(x)));
        return detail.Length == 0 ? q.Name : $"{q.Name} ({detail})";
    }

    private static void Validate(SaveTeacherDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.FirstName) || string.IsNullOrWhiteSpace(dto.LastName))
            throw new ValidationException("First and last name are required.");
        if (string.IsNullOrWhiteSpace(dto.Subject))
            throw new ValidationException("Subject is required.");
        if (string.IsNullOrWhiteSpace(dto.Phone))
            throw new ValidationException("Phone is required.");
    }

    private static StaffMember Map(StaffMember t, SaveTeacherDto d)
    {
        t.FirstName = d.FirstName.Trim();
        t.LastName = d.LastName.Trim();
        t.Specialization = d.Subject?.Trim();
        t.Phone = d.Phone?.Trim();
        t.Email = d.Email;
        // staff.qualification stays a joined summary: the teacher portal and profile screens
        // already read that single column, and the rows are the source of truth.
        var joined = string.Join("; ", Qualifications(d).Select(Summarise));
        t.Qualification = joined.Length == 0 ? null : (joined.Length > 255 ? joined[..255] : joined);
        t.Gender = d.Gender;
        t.Dob = d.Dob;
        t.Address = d.Address;
        t.City = d.City;
        t.State = d.State;
        t.Pincode = d.Pincode;
        return t;
    }
}
