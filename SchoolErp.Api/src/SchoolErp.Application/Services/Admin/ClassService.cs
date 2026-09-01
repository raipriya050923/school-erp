using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services.Admin;

public class ClassService : IClassService
{
    private readonly IClassRepository _repo;
    private readonly ICurrentSchool _school;

    public ClassService(IClassRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    public async Task<IReadOnlyList<ClassDto>> ListAsync(CancellationToken ct = default)
    {
        var classes = await _repo.GetAllWithSectionsAsync(_school.SchoolId, ct);
        return classes.Select(c => new ClassDto(c.Id, c.Name,
            c.Sections.Select(s => new SectionDto(s.Id, s.ClassId, s.Name, s.Teacher, s.StudentCount)).ToList())).ToList();
    }

    public async Task<long> CreateClassAsync(CreateClassDto dto, CancellationToken ct = default)
    {
        var name = dto.Name?.Trim() ?? "";
        if (name.Length == 0) throw new ValidationException("Class name is required.");
        if (await _repo.ExistsByNameAsync(_school.SchoolId, name, null, ct))
            throw new ValidationException($"“{name}” already exists.");

        var classId = await _repo.CreateClassAsync(_school.SchoolId, name, ct);
        if (!string.IsNullOrWhiteSpace(dto.SectionName))
            await _repo.AddSectionAsync(_school.SchoolId, classId, dto.SectionName!.Trim().ToUpperInvariant(), dto.Teacher, ct);
        return classId;
    }

    public async Task RenameClassAsync(long id, string name, CancellationToken ct = default)
    {
        name = name?.Trim() ?? "";
        if (name.Length == 0) throw new ValidationException("Class name is required.");
        _ = await _repo.GetByIdAsync(_school.SchoolId, id, ct) ?? throw new NotFoundException($"Class {id} not found.");
        if (await _repo.ExistsByNameAsync(_school.SchoolId, name, id, ct))
            throw new ValidationException($"“{name}” already exists.");
        await _repo.RenameClassAsync(_school.SchoolId, id, name, ct);
    }

    public async Task DeleteClassAsync(long id, CancellationToken ct = default)
    {
        var cls = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
                  ?? throw new NotFoundException($"Class {id} not found.");

        // Refuse where real records would be orphaned; subject picks, teacher assignments and
        // timetable slots go with the class, so those never block it.
        var usage = await _repo.GetClassUsageAsync(_school.SchoolId, id, ct);
        if (usage.Any)
            throw new ValidationException($"{cls.Name} cannot be deleted — {Describe(usage)}.");

        await _repo.DeleteClassAsync(_school.SchoolId, id, ct);
    }

    /// <summary>Names what is in the way, so the admin knows what to clear first.</summary>
    private static string Describe(ClassUsage u)
    {
        var parts = new List<string>();
        if (u.Students > 0) parts.Add($"{u.Students} student(s) are in it");
        if (u.Enrollments > 0) parts.Add($"{u.Enrollments} enrolment record(s) reference it");
        if (u.FeeStructures > 0) parts.Add($"{u.FeeStructures} fee structure(s) are set for it");
        if (u.ExamSchedules > 0) parts.Add($"{u.ExamSchedules} exam schedule(s) use it");
        return string.Join(", and ", parts) + ". Move or remove those first";
    }

    public async Task<long> AddSectionAsync(SaveSectionDto dto, CancellationToken ct = default)
    {
        var name = dto.Name?.Trim().ToUpperInvariant() ?? "";
        if (dto.ClassId == 0 || name.Length == 0) throw new ValidationException("Class and section name are required.");
        if (await _repo.SectionExistsAsync(dto.ClassId, name, null, ct))
            throw new ValidationException($"Section {name} already exists in this class.");
        return await _repo.AddSectionAsync(_school.SchoolId, dto.ClassId, name, dto.Teacher, ct);
    }

    public async Task UpdateSectionAsync(long id, SaveSectionDto dto, CancellationToken ct = default)
    {
        var name = dto.Name?.Trim().ToUpperInvariant() ?? "";
        if (name.Length == 0) throw new ValidationException("Section name is required.");
        if (await _repo.SectionExistsAsync(dto.ClassId, name, id, ct))
            throw new ValidationException($"Section {name} already exists in this class.");
        await _repo.UpdateSectionAsync(_school.SchoolId, id, name, dto.Teacher, ct);
    }

    public async Task DeleteSectionAsync(long id, CancellationToken ct = default)
    {
        var usage = await _repo.GetSectionUsageAsync(_school.SchoolId, id, ct);
        if (usage.Any)
            throw new ValidationException($"This section cannot be deleted — {Describe(usage)}.");
        await _repo.DeleteSectionAsync(_school.SchoolId, id, ct);
    }
}
