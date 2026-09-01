using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Auth;

public class AuthService : IAuthService
{
    private readonly IUserRepository _users;
    private readonly IPasswordHasher _hasher;
    private readonly INotificationSender _notifier;
    private readonly ITokenService _tokens;
    private readonly ISchoolRepository _schools;
    private readonly ISubscriptionRepository _subscriptions;

    public AuthService(IUserRepository users, IPasswordHasher hasher, INotificationSender notifier,
        ITokenService tokens, ISchoolRepository schools, ISubscriptionRepository subscriptions)
    {
        _users = users;
        _hasher = hasher;
        _notifier = notifier;
        _tokens = tokens;
        _schools = schools;
        _subscriptions = subscriptions;
    }

    public async Task<AuthUserDto> LoginAsync(LoginDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
            throw new ValidationException("Username and password are required.");

        var user = await _users.GetByUsernameOrEmailAsync(dto.Username.Trim(), ct);
        if (user is null || !_hasher.Verify(dto.Password, user.PasswordHash))
            throw new ValidationException("Invalid username or password.");
        if (!user.IsActive)
            throw new ValidationException("This account is disabled. Contact your administrator.");
        if (user.UserType != "super_admin" && user.SchoolId is null)
            throw new ValidationException("This account is not linked to a school. Contact your administrator.");
        // Platform staff must stay able to sign in and fix a lapsed tenant, so they skip this.
        if (user.UserType != "super_admin" && user.SchoolId is { } tenantId)
            await EnsureTenantIsUsableAsync(tenantId, ct);

        // The portals key off staff/student rows rather than the login itself, so resolve those
        // once here and carry them in the token instead of looking them up on every request.
        var staffId = user.UserType is "teacher" or "staff" ? await _users.GetStaffIdAsync(user.Id, ct) : null;
        var studentId = user.UserType == "student" ? await _users.GetStudentIdAsync(user.Id, ct) : null;

        var (token, expiresAt) = _tokens.Issue(
            new TokenIdentity(user.Id, user.SchoolId, user.UserType, user.Username, staffId, studentId));

        return ToAuthUser(user, token, expiresAt);
    }

    public async Task ChangePasswordAsync(ChangePasswordDto dto, CancellationToken ct = default)
    {
        var user = await _users.GetByUsernameOrEmailAsync(dto.Username.Trim(), ct)
                   ?? throw new NotFoundException("User not found.");
        if (!_hasher.Verify(dto.CurrentPassword, user.PasswordHash))
            throw new ValidationException("Current password is incorrect.");
        ValidateNewPassword(dto.NewPassword);
        await _users.UpdatePasswordAsync(user.Id, _hasher.Hash(dto.NewPassword), ct);
    }

    public async Task<ForgotPasswordResultDto> ForgotPasswordAsync(ForgotPasswordDto dto, CancellationToken ct = default)
    {
        var email = dto.Email.Trim();
        var user = await _users.GetByEmailAsync(email, ct);
        // Always respond the same way so we don't leak which emails exist.
        if (user is null)
            return new ForgotPasswordResultDto("If that email exists, a reset link has been sent.", null);

        var token = Guid.NewGuid().ToString("N");
        await _users.CreateResetTokenAsync(user.Id, token, DateTime.UtcNow.AddHours(1), ct);
        await _notifier.SendEmailAsync(email, "Password reset",
            $"Use this token to reset your password (valid 1 hour): {token}", ct);

        // DemoToken is returned so the flow is testable without a real inbox — remove in production.
        return new ForgotPasswordResultDto("If that email exists, a reset link has been sent.", token);
    }

    public async Task ResetPasswordAsync(ResetPasswordDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Token))
            throw new ValidationException("Reset token is required.");
        var row = await _users.GetResetTokenAsync(dto.Token.Trim(), ct)
                  ?? throw new ValidationException("Invalid or expired reset token.");
        if (row.used || row.expiresAt < DateTime.UtcNow)
            throw new ValidationException("This reset token has expired or already been used.");

        ValidateNewPassword(dto.NewPassword);
        await _users.UpdatePasswordAsync(row.userId, _hasher.Hash(dto.NewPassword), ct);
        await _users.MarkResetTokenUsedAsync(dto.Token.Trim(), ct);
    }

    /// <summary>
    /// Refuses sign-in for a tenant that has been shut off. Judged on the stored statuses only,
    /// never on <c>end_date</c>: nothing advances a lapsed subscription to 'expired' yet, so
    /// dating the check would lock out every school whose seeded period has simply run out.
    /// </summary>
    private async Task EnsureTenantIsUsableAsync(long schoolId, CancellationToken ct)
    {
        var school = await _schools.GetByIdAsync(schoolId, ct);
        if (school is null)
            throw new ValidationException("This school no longer exists. Contact support.");
        if (school.Status is "suspended")
            throw new ValidationException("This school is suspended. Contact your platform administrator.");
        if (school.Status is "terminated")
            throw new ValidationException("This school's account has been closed. Contact your platform administrator.");

        // A school that never had a subscription is left alone — blocking it would strand tenants
        // onboarded before plans were required.
        var sub = await _subscriptions.GetLatestBySchoolAsync(schoolId, ct);
        if (sub?.Status is "expired" or "cancelled")
            throw new ValidationException("This school's subscription has ended. Contact your platform administrator.");
    }

    private static void ValidateNewPassword(string pw)
    {
        if (string.IsNullOrWhiteSpace(pw) || pw.Length < 6)
            throw new ValidationException("New password must be at least 6 characters.");
    }

    private static AuthUserDto ToAuthUser(User u, string token, DateTime expiresAt)
    {
        var (role, portal, title) = MapRole(u);
        return new AuthUserDto(u.Id, u.SchoolId, u.UserType, role, u.Username, u.Email, u.FullName,
            portal, title, token, expiresAt);
    }

    private static (string role, string portal, string title) MapRole(User u) => u.UserType switch
    {
        "super_admin" => ("super_admin", "/super-admin", "Platform Owner"),
        "school_admin" => ("school_admin", "/admin", "Administrator"),
        "teacher" => ("teacher", "/teacher", "Teacher"),
        "student" => ("student", "/student", "Student"),
        _ => (u.UserType, "/login", u.UserType),
    };
}
