using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Auth;

/// <inheritdoc />
public class AccountProvisioner : IAccountProvisioner
{
    private readonly IUserRepository _users;
    private readonly IPasswordHasher _hasher;
    private readonly AccountOptions _options;

    public AccountProvisioner(IUserRepository users, IPasswordHasher hasher, AccountOptions options)
    {
        _users = users;
        _hasher = hasher;
        _options = options;
    }

    public async Task<GeneratedCredentialsDto> ProvisionAsync(
        long schoolId, string userType, string usernameStem, string fullName,
        string? email, string? phone, CancellationToken ct = default)
    {
        var username = await UniqueUsernameAsync(usernameStem, ct);
        // A configured fixed password is a dev shortcut; unset it and every account gets a random one.
        var password = string.IsNullOrWhiteSpace(_options.FixedPassword)
            ? CredentialGenerator.Password()
            : _options.FixedPassword;

        // Password reset looks users up by email across all tenants, so a duplicate address would
        // make one of the two accounts unrecoverable. Registration is not worth blocking over
        // that (siblings share a parent's address), so the clash just drops the email instead.
        var storedEmail = string.IsNullOrWhiteSpace(email) ? null : email.Trim();
        if (storedEmail is not null && await _users.GetByEmailAsync(storedEmail, ct) is not null)
            storedEmail = null;

        var userId = await _users.CreateAsync(new User
        {
            SchoolId = schoolId,
            UserType = userType,
            Username = username,
            Email = storedEmail,
            Phone = string.IsNullOrWhiteSpace(phone) ? null : phone.Trim(),
            PasswordHash = _hasher.Hash(password),
            FullName = Truncate(fullName, 150),
            IsActive = true,
        }, ct);

        return new GeneratedCredentialsDto(userId, fullName, username, storedEmail, password);
    }

    /// <summary>Appends a counter until the stem is free, since logins resolve across all tenants.</summary>
    private async Task<string> UniqueUsernameAsync(string stem, CancellationToken ct)
    {
        if (!await _users.UsernameExistsAsync(stem, ct)) return stem;
        for (var n = 2; n <= 999; n++)
        {
            var candidate = $"{stem}{n}";
            if (!await _users.UsernameExistsAsync(candidate, ct)) return candidate;
        }
        throw new ValidationException($"Could not derive a free username from '{stem}'.");
    }

    private static string Truncate(string s, int max) => s.Length <= max ? s : s[..max];
}
