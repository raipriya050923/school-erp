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

    public StudentService(IStudentRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    public async Task<IReadOnlyList<StudentListItemDto>> ListAsync(string? search, string? className, CancellationToken ct = default)
    {
        var rows = await _repo.GetAllAsync(_school.SchoolId, search, className, ct);
        return rows.Select(s => new StudentListItemDto(
            s.Id, s.AdmissionNo, $"{s.FirstName} {s.LastName}".Trim(), s.ClassName, s.SectionName,
            s.RollNo, s.GuardianName, s.GuardianPhone, s.FeeDue, s.Status, s.AdmissionDate)).ToList();
    }

    public async Task<StudentDetailDto?> GetAsync(long id, CancellationToken ct = default)
    {
        var s = await _repo.GetByIdAsync(_school.SchoolId, id, ct);
        if (s is null) return null;
        return new StudentDetailDto(s.Id, s.AdmissionNo, $"{s.FirstName} {s.LastName}".Trim(),
            s.FirstName, s.LastName, s.ClassName, s.SectionName, s.RollNo, s.Gender, s.Dob,
            s.BloodGroup, s.Email, s.Phone, s.GuardianName, s.GuardianPhone, s.Address, s.City,
            s.State, s.Pincode, s.PreviousSchool, s.AdmissionDate, s.FeeDue, s.Status);
    }

    public async Task<long> CreateAsync(SaveStudentDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        var s = Map(new Student { SchoolId = _school.SchoolId }, dto);
        s.AdmissionNo = await _repo.NextAdmissionNoAsync(_school.SchoolId, ct);
        s.AdmissionDate = DateTime.UtcNow;
        s.Status = "active";
        return await _repo.CreateAsync(s, ct);
    }

    public async Task UpdateAsync(long id, SaveStudentDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        var s = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
                ?? throw new NotFoundException($"Student {id} not found.");
        Map(s, dto);
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
        return s;
    }
}
