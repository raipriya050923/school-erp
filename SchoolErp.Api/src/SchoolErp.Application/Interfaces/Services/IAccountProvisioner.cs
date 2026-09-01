using SchoolErp.Application.DTOs.Auth;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>
/// Creates the login account that goes with a newly registered person, and hands back the
/// one and only copy of the generated password.
/// </summary>
public interface IAccountProvisioner
{
    /// <summary>
    /// Creates a <c>users</c> row for the person and returns their credentials. The plaintext
    /// password exists only in the returned DTO — the database stores a bcrypt hash — so the
    /// caller must surface it immediately or it is lost.
    /// </summary>
    /// <param name="usernameStem">Preferred username; a counter is appended if it is taken.</param>
    /// <param name="email">
    /// Contact email. Stored only when free across all tenants, since password reset resolves
    /// users by email globally; otherwise the account is username-only.
    /// </param>
    Task<GeneratedCredentialsDto> ProvisionAsync(
        long schoolId, string userType, string usernameStem, string fullName,
        string? email, string? phone, CancellationToken ct = default);
}
