using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

public class SchoolService : ISchoolService
{
    private static readonly string[] ValidStatuses = { "pending", "active", "suspended", "terminated" };
    private readonly ISchoolRepository _schools;

    public SchoolService(ISchoolRepository schools) => _schools = schools;

    public async Task<IReadOnlyList<SchoolListItemDto>> ListAsync(string? search, string? status, CancellationToken ct = default)
    {
        var rows = await _schools.GetAllAsync(search, status, ct);
        var list = new List<SchoolListItemDto>(rows.Count);
        foreach (var s in rows)
        {
            var students = await _schools.GetStudentCountAsync(s.Id, ct);
            list.Add(new SchoolListItemDto(s.Id, s.SchoolCode, s.Name, s.City, s.Status, null, students, s.CreatedAt));
        }
        return list;
    }

    public async Task<SchoolDetailDto?> GetAsync(long id, CancellationToken ct = default)
    {
        var s = await _schools.GetByIdAsync(id, ct);
        if (s is null) return null;
        return new SchoolDetailDto(s.Id, s.SchoolCode, s.Name, s.Subdomain, s.Email, s.Phone,
            s.City, s.State, s.Country, s.PostalCode, s.AffiliationBoard, s.Currency, s.Timezone,
            s.Status, s.OnboardedAt, s.CreatedAt);
    }

    public async Task<long> CreateAsync(CreateSchoolDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Name))
            throw new ValidationException("School name is required.");
        if (await _schools.ExistsByNameAsync(dto.Name.Trim(), null, ct))
            throw new ValidationException($"A school named '{dto.Name}' already exists.");

        var slug = Slugify(dto.Name);
        var school = new School
        {
            Name = dto.Name.Trim(),
            SchoolCode = GenerateCode(dto.Name),
            Subdomain = slug,
            Email = dto.Email.Trim(),
            Phone = dto.Phone.Trim(),
            City = dto.City,
            State = dto.State,
            Country = dto.Country,
            PostalCode = dto.PostalCode,
            AffiliationBoard = dto.AffiliationBoard,
            Status = ValidStatuses.Contains(dto.Status) ? dto.Status : "pending",
            OnboardedAt = dto.Status == "active" ? DateTime.UtcNow : null,
        };
        return await _schools.CreateAsync(school, ct);
    }

    public async Task UpdateAsync(long id, UpdateSchoolDto dto, CancellationToken ct = default)
    {
        var s = await _schools.GetByIdAsync(id, ct) ?? throw new NotFoundException($"School {id} not found.");
        if (string.IsNullOrWhiteSpace(dto.Name))
            throw new ValidationException("School name is required.");
        if (await _schools.ExistsByNameAsync(dto.Name.Trim(), id, ct))
            throw new ValidationException($"A school named '{dto.Name}' already exists.");

        s.Name = dto.Name.Trim();
        s.Email = dto.Email.Trim();
        s.Phone = dto.Phone.Trim();
        s.City = dto.City;
        s.State = dto.State;
        s.Country = dto.Country;
        s.PostalCode = dto.PostalCode;
        s.AffiliationBoard = dto.AffiliationBoard;
        if (ValidStatuses.Contains(dto.Status)) s.Status = dto.Status;
        await _schools.UpdateAsync(s, ct);
    }

    public async Task ChangeStatusAsync(long id, string status, CancellationToken ct = default)
    {
        if (!ValidStatuses.Contains(status))
            throw new ValidationException($"Invalid status '{status}'.");
        _ = await _schools.GetByIdAsync(id, ct) ?? throw new NotFoundException($"School {id} not found.");
        await _schools.UpdateStatusAsync(id, status, ct);
    }

    private static string Slugify(string name) =>
        new string(name.ToLowerInvariant().Select(c => char.IsLetterOrDigit(c) ? c : '-').ToArray())
            .Trim('-').Replace("--", "-");

    private static string GenerateCode(string name)
    {
        var initials = new string(name.Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Select(w => char.ToUpperInvariant(w[0])).Where(char.IsLetter).ToArray());
        if (initials.Length < 3) initials = (initials + "XXX")[..3];
        else initials = initials[..3];
        return $"{initials}{DateTime.UtcNow:HHmmss}";
    }
}
