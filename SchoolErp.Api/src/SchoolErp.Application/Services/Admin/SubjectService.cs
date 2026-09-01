using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

public class SubjectService : ISubjectService
{
    private static readonly string[] ValidTypes = { "theory", "practical", "both" };
    private readonly ISubjectRepository _repo;
    private readonly ICurrentSchool _school;

    public SubjectService(ISubjectRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    public async Task<IReadOnlyList<SubjectDto>> ListAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetAllAsync(_school.SchoolId, ct);
        if (rows.Count == 0)
        {
            // Schools created before subjects existed have none, which would leave both this screen
            // and the exam dropdown empty. Give them the default set on first use.
            await _repo.SeedDefaultsAsync(_school.SchoolId, ct);
            rows = await _repo.GetAllAsync(_school.SchoolId, ct);
        }
        return rows.Select(s => new SubjectDto(s.Id, s.Name, s.Code, s.SubjectType, s.IsActive)).ToList();
    }

    public async Task<IReadOnlyList<string>> ActiveNamesAsync(CancellationToken ct = default)
    {
        var names = await _repo.GetNamesAsync(_school.SchoolId, ct);
        if (names.Count > 0) return names;
        await _repo.SeedDefaultsAsync(_school.SchoolId, ct);
        return await _repo.GetNamesAsync(_school.SchoolId, ct);
    }

    public async Task<long> CreateAsync(SaveSubjectDto dto, CancellationToken ct = default)
    {
        var name = Validate(dto);
        if (await _repo.ExistsByNameAsync(_school.SchoolId, name, null, ct))
            throw new ValidationException($"“{name}” already exists.");

        return await _repo.CreateAsync(new Subject
        {
            SchoolId = _school.SchoolId,
            Name = name,
            Code = string.IsNullOrWhiteSpace(dto.Code) ? null : dto.Code.Trim().ToUpperInvariant(),
            SubjectType = ValidTypes.Contains(dto.SubjectType) ? dto.SubjectType : "theory",
            IsActive = true,
        }, ct);
    }

    public async Task UpdateAsync(long id, SaveSubjectDto dto, CancellationToken ct = default)
    {
        var name = Validate(dto);
        var subject = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
                      ?? throw new NotFoundException($"Subject {id} not found.");
        if (await _repo.ExistsByNameAsync(_school.SchoolId, name, id, ct))
            throw new ValidationException($"“{name}” already exists.");

        subject.Name = name;
        subject.Code = string.IsNullOrWhiteSpace(dto.Code) ? null : dto.Code.Trim().ToUpperInvariant();
        subject.SubjectType = ValidTypes.Contains(dto.SubjectType) ? dto.SubjectType : subject.SubjectType;
        await _repo.UpdateAsync(subject, ct);
    }

    public async Task SetActiveAsync(long id, bool isActive, CancellationToken ct = default)
    {
        _ = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
            ?? throw new NotFoundException($"Subject {id} not found.");
        await _repo.SetActiveAsync(_school.SchoolId, id, isActive, ct);
    }

    private static string Validate(SaveSubjectDto dto)
    {
        var name = dto.Name?.Trim() ?? "";
        if (name.Length == 0) throw new ValidationException("Subject name is required.");
        return name;
    }
}
