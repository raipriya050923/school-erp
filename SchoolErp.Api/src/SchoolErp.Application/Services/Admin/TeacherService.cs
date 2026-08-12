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

    public TeacherService(ITeacherRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    public async Task<IReadOnlyList<TeacherListItemDto>> ListAsync(string? search, CancellationToken ct = default)
    {
        var rows = await _repo.GetAllAsync(_school.SchoolId, search, ct);
        return rows.Select(t => new TeacherListItemDto(
            t.Id, t.EmployeeCode, $"{t.FirstName} {t.LastName}".Trim(), t.Specialization,
            t.ClassesTaught, t.Phone, t.Email, t.Status, t.JoiningDate)).ToList();
    }

    public async Task<TeacherDetailDto?> GetAsync(long id, CancellationToken ct = default)
    {
        var t = await _repo.GetByIdAsync(_school.SchoolId, id, ct);
        if (t is null) return null;
        return new TeacherDetailDto(t.Id, t.EmployeeCode, $"{t.FirstName} {t.LastName}".Trim(),
            t.FirstName, t.LastName, t.Specialization, t.ClassesTaught, t.Phone, t.Email,
            t.Qualification, t.Gender, t.Dob, t.Address, t.City, t.State, t.Pincode, t.JoiningDate, t.Status);
    }

    public async Task<long> CreateAsync(SaveTeacherDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        var t = Map(new StaffMember { SchoolId = _school.SchoolId, StaffType = "teacher" }, dto);
        t.EmployeeCode = await _repo.NextEmployeeCodeAsync(_school.SchoolId, ct);
        t.JoiningDate = DateTime.UtcNow;
        t.Status = "active";
        return await _repo.CreateAsync(t, ct);
    }

    public async Task UpdateAsync(long id, SaveTeacherDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        var t = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
                ?? throw new NotFoundException($"Teacher {id} not found.");
        Map(t, dto);
        await _repo.UpdateAsync(t, ct);
    }

    public async Task SetStatusAsync(long id, string status, CancellationToken ct = default)
    {
        if (!Statuses.Contains(status)) throw new ValidationException($"Invalid status '{status}'.");
        _ = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
            ?? throw new NotFoundException($"Teacher {id} not found.");
        await _repo.SetStatusAsync(_school.SchoolId, id, status, ct);
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
        t.ClassesTaught = d.ClassesTaught;
        t.Phone = d.Phone?.Trim();
        t.Email = d.Email;
        t.Qualification = d.Qualification;
        t.Gender = d.Gender;
        t.Dob = d.Dob;
        t.Address = d.Address;
        t.City = d.City;
        t.State = d.State;
        t.Pincode = d.Pincode;
        return t;
    }
}
