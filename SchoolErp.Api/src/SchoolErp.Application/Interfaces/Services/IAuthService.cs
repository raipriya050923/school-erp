using SchoolErp.Application.DTOs.Auth;

namespace SchoolErp.Application.Interfaces.Services;

public interface IAuthService
{
    Task<AuthUserDto> LoginAsync(LoginDto dto, CancellationToken ct = default);
    Task ChangePasswordAsync(ChangePasswordDto dto, CancellationToken ct = default);
    Task<ForgotPasswordResultDto> ForgotPasswordAsync(ForgotPasswordDto dto, CancellationToken ct = default);
    Task ResetPasswordAsync(ResetPasswordDto dto, CancellationToken ct = default);
}

/// <summary>Abstraction over password hashing (BCrypt in Infrastructure).</summary>
/// <summary>Builds the signed-in user's own profile, whatever their role.</summary>
public interface IProfileService
{
    Task<MyProfileDto> GetMineAsync(CancellationToken ct = default);
}

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
}
