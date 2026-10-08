using Microsoft.Extensions.Logging;
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
    private readonly INotificationSender _mail;
    private readonly ISchoolRepository _schools;
    private readonly ILogger<AccountProvisioner> _logger;

    public AccountProvisioner(IUserRepository users, IPasswordHasher hasher, AccountOptions options,
        INotificationSender mail, ISchoolRepository schools, ILogger<AccountProvisioner> logger)
    {
        _users = users;
        _hasher = hasher;
        _options = options;
        _mail = mail;
        _schools = schools;
        _logger = logger;
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
            // The password here is one an administrator will read off a screen — in development
            // it is the shared fixed password. It gets the holder in; it is not their secret yet.
            MustChangePassword = true,
        }, ct);

        // Told, not just created. The password is still only in memory at this point, which is
        // the one moment it can be sent — the database holds a hash and nothing can recover it.
        await TrySendWelcomeAsync(schoolId, userType, fullName, username, password, storedEmail, ct);

        return new GeneratedCredentialsDto(userId, fullName, username, storedEmail, password);
    }

    /// <summary>
    /// Emails the new account its credentials, and never lets that failure reach the caller.
    ///
    /// A student must still be admitted when the mail server is down, the mailbox is full, or the
    /// address turns out to be a typo. The administrator sees the password on screen either way,
    /// so a failed send costs a convenience, not the registration — but it is logged loudly,
    /// because silently not telling people their login is its own kind of broken.
    /// </summary>
    private async Task TrySendWelcomeAsync(long schoolId, string userType, string fullName,
        string username, string password, string? email, CancellationToken ct)
    {
        if (!_options.SendWelcomeEmail) return;
        if (string.IsNullOrWhiteSpace(email))
        {
            // Not an error: students are routinely admitted without one, and a duplicate address
            // is dropped earlier on purpose. Recorded so "they never got the email" has an answer.
            _logger.LogInformation(
                "No welcome email for {Username}: the account has no address of its own", username);
            return;
        }

        try
        {
            var school = await _schools.GetByIdAsync(schoolId, ct);
            var schoolName = school?.Name ?? string.Empty;
            var role = WelcomeEmail.RoleLabel(userType);

            await _mail.SendEmailAsync(
                email,
                WelcomeEmail.Subject(schoolName),
                WelcomeEmail.HtmlBody(fullName, schoolName, role, username, password, _options.PortalUrl, userType),
                WelcomeEmail.PlainBody(fullName, schoolName, role, username, password, _options.PortalUrl, userType),
                ct);

            _logger.LogInformation("Welcome email sent to {Email} for {Username}", email, username);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Welcome email to {Email} for {Username} failed. The account exists and the password " +
                "was shown to the administrator; it can be re-issued with a password reset", email, username);
        }
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
