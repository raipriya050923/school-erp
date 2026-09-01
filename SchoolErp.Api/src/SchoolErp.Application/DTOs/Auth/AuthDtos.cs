namespace SchoolErp.Application.DTOs.Auth;

public class LoginDto
{
    public string Username { get; set; } = string.Empty;   // username or email
    public string Password { get; set; } = string.Empty;
}

/// <summary>
/// The login response. <paramref name="Token"/> is the bearer token every subsequent request must
/// carry — it holds the signed school id that scopes the caller to their own tenant.
/// </summary>
public record AuthUserDto(
    long Id, long? SchoolId, string UserType, string Role, string Username,
    string? Email, string FullName, string PortalPath, string Title,
    string Token, DateTime ExpiresAtUtc);

/// <summary>
/// Credentials for a freshly created account, returned once. <paramref name="TemporaryPassword"/>
/// is plaintext and is never retrievable again — only its bcrypt hash is stored — so it must be
/// shown to the admin straight away and never written to logs or local storage.
/// <paramref name="Email"/> is null when the address was already taken by another account, in
/// which case the person signs in by username only.
/// </summary>
public record GeneratedCredentialsDto(
    long UserId, string FullName, string Username, string? Email, string TemporaryPassword);

/// <summary>One labelled row on the profile page, e.g. "Employee code" / "EMP-014".</summary>
public record ProfileDetailDto(string Label, string? Value);

/// <summary>
/// The signed-in user's own profile. Role-specific rows arrive as a flat label/value list so a
/// single page can render a super admin, school admin, teacher or student without branching.
/// </summary>
public record MyProfileDto(
    long UserId,
    string Username,
    string FullName,
    string? Email,
    string? Phone,
    string Role,
    string Title,
    long? SchoolId,
    string? SchoolName,
    IReadOnlyList<ProfileDetailDto> Details);

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
