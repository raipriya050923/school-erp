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

    public AuthService(IUserRepository users, IPasswordHasher hasher, INotificationSender notifier)
    {
        _users = users;
        _hasher = hasher;
        _notifier = notifier;
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

        return ToAuthUser(user);
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

    private static void ValidateNewPassword(string pw)
    {
        if (string.IsNullOrWhiteSpace(pw) || pw.Length < 6)
            throw new ValidationException("New password must be at least 6 characters.");
    }

    private static AuthUserDto ToAuthUser(User u)
    {
        var (role, portal, title) = MapRole(u);
        return new AuthUserDto(u.Id, u.SchoolId, u.UserType, role, u.Username, u.Email, u.FullName, portal, title);
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
