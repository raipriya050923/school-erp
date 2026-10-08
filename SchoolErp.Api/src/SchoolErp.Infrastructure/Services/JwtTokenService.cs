using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Signs access tokens with the shared secret in <c>Jwt:Key</c>. The school id travels as a
/// signed claim, so a caller cannot widen their own scope by editing the request.
/// </summary>
public class JwtTokenService : ITokenService
{
    private readonly JwtOptions _options;

    public JwtTokenService(IConfiguration config) => _options = JwtOptions.From(config);

    public (string token, DateTime expiresAtUtc) Issue(TokenIdentity identity)
    {
        var expiresAt = DateTime.UtcNow.AddMinutes(_options.ExpiryMinutes);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, identity.UserId.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
            new(ErpClaims.UserId, identity.UserId.ToString()),
            new(ErpClaims.UserType, identity.UserType),
            // Role claim so [Authorize(Roles = "school_admin")] works without extra mapping.
            new(ClaimTypes.Role, identity.UserType),
            new(ClaimTypes.Name, identity.Username),
        };
        if (identity.SchoolId is { } school) claims.Add(new Claim(ErpClaims.SchoolId, school.ToString()));
        if (identity.StaffId is { } staff) claims.Add(new Claim(ErpClaims.StaffId, staff.ToString()));
        if (identity.StudentId is { } student) claims.Add(new Claim(ErpClaims.StudentId, student.ToString()));
        // Only added when true, so an ordinary token carries nothing extra.
        if (identity.MustChangePassword) claims.Add(new Claim(ErpClaims.MustChangePassword, "1"));

        var credentials = new SigningCredentials(_options.SigningKey, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: expiresAt,
            signingCredentials: credentials);

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }
}

/// <summary>Shared by the issuer and the API's bearer-token validation so both agree.</summary>
public sealed class JwtOptions
{
    public string Issuer { get; init; } = "SchoolErp";
    public string Audience { get; init; } = "SchoolErpClient";
    public int ExpiryMinutes { get; init; } = 480;
    public SymmetricSecurityKey SigningKey { get; init; } = default!;

    public static JwtOptions From(IConfiguration config)
    {
        var key = config["Jwt:Key"];
        if (string.IsNullOrWhiteSpace(key) || key.Length < 32)
            throw new InvalidOperationException(
                "Jwt:Key must be configured with at least 32 characters. Set it in appsettings.json or as an environment variable.");

        return new JwtOptions
        {
            Issuer = config["Jwt:Issuer"] ?? "SchoolErp",
            Audience = config["Jwt:Audience"] ?? "SchoolErpClient",
            ExpiryMinutes = int.TryParse(config["Jwt:ExpiryMinutes"], out var m) ? m : 480,
            SigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
        };
    }
}
