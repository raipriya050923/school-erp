namespace SchoolErp.Application.DTOs.Auth;

public class LoginDto
{
    public string Username { get; set; } = string.Empty;   // username or email
    public string Password { get; set; } = string.Empty;
}

public record AuthUserDto(
    long Id, long? SchoolId, string UserType, string Role, string Username,
    string? Email, string FullName, string PortalPath, string Title);

public class ChangePasswordDto
{
    public string Username { get; set; } = string.Empty;
    public string CurrentPassword { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}

public class ForgotPasswordDto
{
    public string Email { get; set; } = string.Empty;
}

public record ForgotPasswordResultDto(string Message, string? DemoToken);

public class ResetPasswordDto
{
    public string Token { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}
