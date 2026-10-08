using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

/// <summary>
/// Issues parent logins from the admin console.
///
/// A parent signs into the student portal: their token carries the child's
/// student id, resolved at login through guardians -> student_guardians. So the
/// job here is to make sure those two rows exist and that the guardian has a
/// user account — there is no separate parent portal to provision.
/// </summary>
public class ParentAccountService : IParentAccountService
{
    private static readonly string[] Relations = { "father", "mother", "guardian", "other" };

    private readonly IGuardianRepository _guardians;
    private readonly IStudentRepository _students;
    private readonly IAccountProvisioner _accounts;
    private readonly ICurrentSchool _school;

    public ParentAccountService(IGuardianRepository guardians, IStudentRepository students,
        IAccountProvisioner accounts, ICurrentSchool school)
    {
        _guardians = guardians;
        _students = students;
        _accounts = accounts;
        _school = school;
    }

    public async Task<ParentAccountDto?> GetAsync(long studentId, CancellationToken ct = default)
    {
        var g = await _guardians.GetForStudentAsync(_school.SchoolId, studentId, ct);
        if (g is null) return null;
        return new ParentAccountDto(g.Id, g.FullName, g.Relation, g.Phone, g.Email,
            g.Username, g.UserId is not null);
    }

    public async Task<GeneratedCredentialsDto> CreateLoginAsync(
        long studentId, CreateParentLoginDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var student = await _students.GetByIdAsync(sid, studentId, ct)
                      ?? throw new NotFoundException($"Student {studentId} not found.");

        var existing = await _guardians.GetForStudentAsync(sid, studentId, ct);
        if (existing?.UserId is not null)
            throw new ValidationException(
                $"{existing.FullName} already has a parent login ({existing.Username}). " +
                "Reset the password instead of issuing a second account.");

        var relation = (dto.Relation ?? "").Trim().ToLowerInvariant();
        if (!Relations.Contains(relation)) relation = "guardian";

        // Fall back to the guardian already captured on the student, so the common
        // case needs no typing at all.
        var (first, last) = SplitName(dto.FirstName, dto.LastName, existing, student.GuardianName);
        if (first.Length == 0)
            throw new ValidationException("A parent name is required — the student has no guardian on file.");

        var phone = Blank(dto.Phone) ?? existing?.Phone ?? student.GuardianPhone;
        if (string.IsNullOrWhiteSpace(phone))
            throw new ValidationException("A contact phone number is required for a parent login.");

        var email = Blank(dto.Email) ?? existing?.Email;

        // Reuse the guardian row when the school already recorded one; a second
        // row would leave the student with two contacts for the same person.
        var guardianId = existing?.Id ?? await _guardians.CreateAsync(new Guardian
        {
            SchoolId = sid,
            FirstName = first,
            LastName = last,
            Relation = relation,
            Phone = phone!,
            Email = email,
        }, ct);

        // The link is what login resolves the child through, so it matters even
        // when the guardian row already existed — an unlinked guardian would
        // leave the parent signing in with nothing to see.
        await _guardians.LinkAsync(studentId, guardianId, isPrimary: existing is null, ct);

        var fullName = $"{first} {last}".Trim();
        var credentials = await _accounts.ProvisionAsync(
            sid, "parent", CredentialGenerator.UsernameStem(first, last), fullName, email, phone, ct);

        await _guardians.SetUserIdAsync(sid, guardianId, credentials.UserId, ct);
        return credentials;
    }

    /// <summary>
    /// Resolves the parent's name from the form, then the guardian record, then
    /// the free-text guardian name on the student — whichever is present first.
    /// </summary>
    private static (string First, string Last) SplitName(
        string? first, string? last, Guardian? existing, string? studentGuardianName)
    {
        if (Blank(first) is { } f) return (f, Blank(last) ?? "");
        if (existing is not null) return (existing.FirstName, existing.LastName);

        var name = (studentGuardianName ?? "").Trim();
        if (name.Length == 0) return ("", "");
        var parts = name.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return (parts[0], parts.Length > 1 ? parts[1] : "");
    }

    private static string? Blank(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
}
