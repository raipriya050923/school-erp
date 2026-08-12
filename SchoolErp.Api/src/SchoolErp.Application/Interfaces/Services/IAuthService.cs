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
public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
}
