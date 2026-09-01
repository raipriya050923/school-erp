using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

/// <inheritdoc />
public class AcademicYearService : IAcademicYearService
{
    private readonly IAcademicYearRepository _repo;
    private readonly ICurrentSchool _school;

    public AcademicYearService(IAcademicYearRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    public async Task<IReadOnlyList<AcademicYearDto>> ListAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetAllAsync(_school.SchoolId, ct);
        var list = new List<AcademicYearDto>(rows.Count);
        foreach (var y in rows)
            list.Add(new AcademicYearDto(y.Id, y.Name, y.StartDate, y.EndDate, y.IsCurrent,
                await _repo.UsageCountAsync(y.Id, ct)));
        return list;
    }

    public async Task<long> CreateAsync(SaveAcademicYearDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var name = await ValidateAsync(sid, dto, null, ct);

        var id = await _repo.CreateAsync(new AcademicYear
        {
            SchoolId = sid, Name = name, StartDate = dto.StartDate, EndDate = dto.EndDate,
        }, ct);

        // The very first year has to be current, or nothing year-scoped would resolve.
        var all = await _repo.GetAllAsync(sid, ct);
        if (all.All(y => !y.IsCurrent)) await _repo.SetCurrentAsync(sid, id, ct);
        return id;
    }

    public async Task UpdateAsync(long id, SaveAcademicYearDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var existing = await _repo.GetByIdAsync(sid, id, ct)
                       ?? throw new NotFoundException($"Academic year {id} not found.");
        var name = await ValidateAsync(sid, dto, id, ct);

        existing.Name = name;
        existing.StartDate = dto.StartDate;
        existing.EndDate = dto.EndDate;
        await _repo.UpdateAsync(existing, ct);
    }

    public async Task SetCurrentAsync(long id, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        _ = await _repo.GetByIdAsync(sid, id, ct)
            ?? throw new NotFoundException($"Academic year {id} not found.");
        await _repo.SetCurrentAsync(sid, id, ct);
    }

    public async Task DeleteAsync(long id, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var year = await _repo.GetByIdAsync(sid, id, ct)
                   ?? throw new NotFoundException($"Academic year {id} not found.");

        if (year.IsCurrent)
            throw new ValidationException(
                "This is the current academic year. Make another year current before deleting it.");

        // class_subjects and teacher_assignments both FK to this row; deleting would strand them.
        var used = await _repo.UsageCountAsync(id, ct);
        if (used > 0)
            throw new ValidationException(
                $"{year.Name} has {used} subject or teacher assignment(s) filed against it and cannot be deleted.");

        await _repo.DeleteAsync(sid, id, ct);
    }

    /// <summary>Shared rules for create and update; returns the trimmed name.</summary>
    private async Task<string> ValidateAsync(long schoolId, SaveAcademicYearDto dto, long? excludeId, CancellationToken ct)
    {
        var name = dto.Name?.Trim() ?? "";
        if (name.Length == 0) throw new ValidationException("Academic year name is required.");
        if (name.Length > 40) throw new ValidationException("Academic year name must be 40 characters or fewer.");
        if (dto.StartDate == default || dto.EndDate == default)
            throw new ValidationException("Start and end dates are required.");
        if (dto.EndDate.Date <= dto.StartDate.Date)
            throw new ValidationException("The end date must fall after the start date.");

        if (await _repo.NameExistsAsync(schoolId, name, excludeId, ct))
            throw new ValidationException($"An academic year named “{name}” already exists.");

        // Overlapping sessions would make "the current year" ambiguous for anything date-driven.
        var clash = await _repo.FindOverlapAsync(schoolId, dto.StartDate, dto.EndDate, excludeId, ct);
        if (clash is not null)
            throw new ValidationException(
                $"These dates overlap {clash.Name} ({clash.StartDate:d MMM yyyy} – {clash.EndDate:d MMM yyyy}).");

        return name;
    }
}
