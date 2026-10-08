using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

/// <summary>
/// Password resets ordered from the admin console.
///
/// Self-service reset already exists, but it mails a token, and most students here were admitted
/// without an email address — so for them the office was the only route back in and had nothing
/// to offer. This closes that: the administrator issues a password, reads it to the holder, and
/// the account is flagged so the holder must replace it the moment they sign in.
///
/// Every path resolves the login through the school's own staff, student or guardian row, so an
/// administrator can only ever reach accounts belonging to their own tenant.
/// </summary>
public class AccountResetService : IAccountResetService
{
    /// <summary>
    /// Account kinds a school administrator may reset. Deliberately excludes school_admin and
    /// super_admin: an administrator who could reset a peer could take their account, and the
    /// platform owner resets those from the super-admin console.
    /// </summary>
    private static readonly string[] Resettable = { "teacher", "staff", "student", "parent" };

    /// <summary>Matches the portal's own rule, so a password set here is one the holder could have chosen.</summary>
    private const int MinPasswordLength = 8;

    private readonly IUserRepository _users;
    private readonly ITeacherRepository _teachers;
    private readonly IStudentRepository _students;
    private readonly IGuardianRepository _guardians;
    private readonly IPasswordHasher _hasher;
    private readonly AccountOptions _options;
    private readonly ICurrentSchool _school;

    public AccountResetService(IUserRepository users, ITeacherRepository teachers,
        IStudentRepository students, IGuardianRepository guardians, IPasswordHasher hasher,
        AccountOptions options, ICurrentSchool school)
    {
        _users = users;
        _teachers = teachers;
        _students = students;
        _guardians = guardians;
        _hasher = hasher;
        _options = options;
        _school = school;
    }

    /* ============================ what the screen asks ============================ */

    public async Task<LoginSummaryDto> TeacherLoginAsync(long staffId, CancellationToken ct = default)
    {
        var staff = await _teachers.GetByIdAsync(_school.SchoolId, staffId, ct)
                    ?? throw new NotFoundException($"Teacher {staffId} not found.");
        return await SummariseAsync(staff.UserId, ct);
    }

    public async Task<LoginSummaryDto> StudentLoginAsync(long studentId, CancellationToken ct = default)
    {
        var student = await _students.GetByIdAsync(_school.SchoolId, studentId, ct)
                      ?? throw new NotFoundException($"Student {studentId} not found.");
        return await SummariseAsync(student.UserId, ct);
    }

    /* ============================ the reset ============================ */

    public async Task<GeneratedCredentialsDto> ResetTeacherAsync(
        long staffId, ResetAccountPasswordDto dto, CancellationToken ct = default)
    {
        var staff = await _teachers.GetByIdAsync(_school.SchoolId, staffId, ct)
                    ?? throw new NotFoundException($"Teacher {staffId} not found.");
        var who = $"{staff.FirstName} {staff.LastName}".Trim();
        return await ResetAsync(staff.UserId, who, "teacher", ct, dto);
    }

    public async Task<GeneratedCredentialsDto> ResetStudentAsync(
        long studentId, ResetAccountPasswordDto dto, CancellationToken ct = default)
    {
        var student = await _students.GetByIdAsync(_school.SchoolId, studentId, ct)
                      ?? throw new NotFoundException($"Student {studentId} not found.");
        var who = $"{student.FirstName} {student.LastName}".Trim();
        return await ResetAsync(student.UserId, who, "student", ct, dto);
    }

    public async Task<GeneratedCredentialsDto> ResetParentAsync(
        long studentId, ResetAccountPasswordDto dto, CancellationToken ct = default)
    {
        var student = await _students.GetByIdAsync(_school.SchoolId, studentId, ct)
                      ?? throw new NotFoundException($"Student {studentId} not found.");
        var guardian = await _guardians.GetForStudentAsync(_school.SchoolId, studentId, ct)
                       ?? throw new ValidationException(
                           $"{student.FirstName} {student.LastName} has no guardian on record, so there is no parent login.");
        return await ResetAsync(guardian.UserId, guardian.FullName, "parent", ct, dto);
    }

    /* ============================ shared ============================ */

    private async Task<LoginSummaryDto> SummariseAsync(long? userId, CancellationToken ct)
    {
        if (userId is not { } id) return new LoginSummaryDto(false, null, null);
        var user = await _users.GetByIdAsync(id, ct);
        if (user is null || user.SchoolId != _school.SchoolId) return new LoginSummaryDto(false, null, null);

        // The holder choosing their own password clears the flag, so this reads as "still on a
        // password the office issued" rather than as a date nobody can interpret.
        var note = user.MustChangePassword
            ? "Has not set their own password yet"
            : user.PasswordChangedAt is { } at ? $"Password last changed {at:d MMM yyyy}" : null;
        return new LoginSummaryDto(true, user.Username, note);
    }

    private async Task<GeneratedCredentialsDto> ResetAsync(
        long? userId, string who, string role, CancellationToken ct, ResetAccountPasswordDto dto)
    {
        if (userId is not { } id)
            throw new ValidationException($"{who} has no portal login yet, so there is no password to reset.");

        var user = await _users.GetByIdAsync(id, ct)
                   ?? throw new ValidationException($"The login attached to {who} no longer exists.");

        // Belt and braces over the tenant-scoped lookup above: if a staff or student row ever
        // pointed at a login outside this school, a reset here would be a cross-tenant takeover.
        if (user.SchoolId != _school.SchoolId)
            throw new NotFoundException($"{role} {id} not found.");

        if (!Resettable.Contains(user.UserType))
            throw new ValidationException(
                $"{who} signs in as a {user.UserType.Replace('_', ' ')}, which cannot be reset from here.");

        var password = ChoosePassword(dto?.NewPassword);
        // mustChange: true — an administrator picked or read this password, so the account is not
        // private to its holder until they replace it. The middleware blocks the portal till then.
        await _users.UpdatePasswordAsync(user.Id, _hasher.Hash(password), true, ct);

        return new GeneratedCredentialsDto(user.Id, string.IsNullOrWhiteSpace(user.FullName) ? who : user.FullName,
            user.Username, user.Email, password);
    }

    /// <summary>
    /// The administrator's password if they typed one, otherwise a generated one. A fixed
    /// development password still wins, so a reset in a demo environment does not strand the
    /// account on a random string while every other login shares a known one.
    /// </summary>
    private string ChoosePassword(string? requested)
    {
        var typed = requested?.Trim();
        if (!string.IsNullOrEmpty(typed))
        {
            if (typed.Length < MinPasswordLength)
                throw new ValidationException($"A password must be at least {MinPasswordLength} characters.");
            return typed;
        }
        return string.IsNullOrWhiteSpace(_options.FixedPassword)
            ? CredentialGenerator.Password()
            : _options.FixedPassword!;
    }
}
