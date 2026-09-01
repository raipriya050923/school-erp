using SchoolErp.Application.DTOs.Auth;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>Issues the signed access token that carries the caller's tenant and identity.</summary>
public interface ITokenService
{
    /// <summary>Returns the encoded JWT and the moment it expires (UTC).</summary>
    (string token, DateTime expiresAtUtc) Issue(TokenIdentity identity);
}

/// <summary>
/// Everything baked into the token. <paramref name="SchoolId"/> is null only for platform
/// (super_admin) accounts, which are not scoped to a tenant.
/// </summary>
public record TokenIdentity(
    long UserId,
    long? SchoolId,
    string UserType,
    string Username,
    long? StaffId,
    long? StudentId);
