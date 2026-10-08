using Microsoft.Extensions.Logging;
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
    private readonly ITokenService _tokens;
    private readonly ISubscriptionGuard _entitlements;
    private readonly ISchoolRepository _schools;
    private readonly AccountOptions _options;
    private readonly ILogger<AuthService> _logger;

    /// <summary>
    /// How long a reset link stays good for. One hour is long enough to find the mail and short
    /// enough that a forwarded or archived message stops being a key. The email quotes this
    /// value rather than repeating the number, so the two cannot disagree.
    /// </summary>
    private static readonly TimeSpan ResetTokenLifetime = TimeSpan.FromHours(1);

    public AuthService(IUserRepository users, IPasswordHasher hasher, INotificationSender notifier,
        ITokenService tokens, ISubscriptionGuard entitlements, ISchoolRepository schools,
        AccountOptions options, ILogger<AuthService> logger)
    {
        _users = users;
        _hasher = hasher;
        _notifier = notifier;
        _tokens = tokens;
        _entitlements = entitlements;
        _schools = schools;
        _options = options;
        _logger = logger;
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
        if (user.UserType != "super_admin" && user.SchoolId is null)
            throw new ValidationException("This account is not linked to a school. Contact your administrator.");
        // Platform staff must stay able to sign in and fix a lapsed tenant, so they skip this.
        if (user.UserType != "super_admin" && user.SchoolId is { } tenantId)
            await EnsureTenantIsUsableAsync(tenantId, ct);

        // The portals key off staff/student rows rather than the login itself, so resolve those
        // once here and carry them in the token instead of looking them up on every request.
        var staffId = user.UserType is "teacher" or "staff" ? await _users.GetStaffIdAsync(user.Id, ct) : null;
        // A parent carries their child's student id, so the whole student portal
        // works for them unchanged — every one of its queries is scoped by this
        // claim rather than by the user, so there is nothing role-specific to
        // duplicate. A parent whose account is not linked to a child is refused
        // here rather than being let in to a portal that would 403 on every screen.
        var studentId = user.UserType switch
        {
            "student" => await _users.GetStudentIdAsync(user.Id, ct),
            "parent" => await _users.GetChildStudentIdAsync(user.Id, ct)
                        ?? throw new ValidationException(
                            "This parent account is not linked to a student. Contact your school office."),
            _ => null,
        };

        var (token, expiresAt) = _tokens.Issue(
            new TokenIdentity(user.Id, user.SchoolId, user.UserType, user.Username, staffId, studentId,
                user.MustChangePassword));

        // Every portal of a school renders in that school's colours, so the palette travels with
        // the session rather than being fetched separately on each shell load.
        var theme = user.SchoolId is { } sid
            ? (await _schools.GetByIdAsync(sid, ct))?.Theme ?? "classic"
            : "classic";

        return ToAuthUser(user, token, expiresAt, theme);
    }

    public async Task ChangePasswordAsync(ChangePasswordDto dto, CancellationToken ct = default)
    {
        var user = await _users.GetByUsernameOrEmailAsync(dto.Username.Trim(), ct)
                   ?? throw new NotFoundException("User not found.");
        if (!_hasher.Verify(dto.CurrentPassword, user.PasswordHash))
            throw new ValidationException("Current password is incorrect.");
        ValidateNewPassword(dto.NewPassword);
        // Reusing the issued password would leave the account exactly as exposed as before.
        if (_hasher.Verify(dto.NewPassword, user.PasswordHash))
            throw new ValidationException("The new password must be different from the current one.");
        // mustChange: false — the holder chose this one, so the flag clears.
        await _users.UpdatePasswordAsync(user.Id, _hasher.Hash(dto.NewPassword), false, ct);
    }

    public async Task<ForgotPasswordResultDto> ForgotPasswordAsync(ForgotPasswordDto dto, CancellationToken ct = default)
    {
        // One reply for every outcome — address unknown, mail server down, link sent. Anything
        // that varies turns this endpoint into a way to ask which addresses hold an account.
        var reply = new ForgotPasswordResultDto("If that email exists, a reset link has been sent.");

        var email = dto.Email.Trim();
        if (string.IsNullOrWhiteSpace(email)) return reply;

        var user = await _users.GetByEmailAsync(email, ct);
        if (user is null)
        {
            _logger.LogInformation("Password reset asked for {Email}, which matches no account", email);
            return reply;
        }

        var token = Guid.NewGuid().ToString("N");
        await _users.CreateResetTokenAsync(user.Id, token, DateTime.UtcNow.Add(ResetTokenLifetime), ct);

        var schoolName = user.SchoolId is { } sid
            ? (await _schools.GetByIdAsync(sid, ct))?.Name ?? string.Empty
            : string.Empty;
        var link = BuildResetLink(token);

        try
        {
            await _notifier.SendEmailAsync(
                email,
                PasswordResetEmail.Subject(schoolName),
                PasswordResetEmail.HtmlBody(user.FullName, schoolName, link, ResetTokenLifetime),
                PasswordResetEmail.PlainBody(user.FullName, schoolName, link, ResetTokenLifetime),
                ct);

            _logger.LogInformation("Password reset link sent to {Email}", email);
        }
        catch (Exception ex)
        {
            // Swallowed on purpose. Letting it out would turn a mail outage into a 500 that only
            // ever fires for addresses that DO exist — the very thing the single reply above is
            // there to hide. The token stays valid; the person can ask again once mail is back.
            _logger.LogError(ex, "Password reset link for {Email} could not be sent", email);
        }

        return reply;
    }

    /// <summary>
    /// The reset page with the token on the query string. Falls back to deriving the page from
    /// PortalUrl (".../login" -> ".../reset-password") so an environment that configured only
    /// the sign-in link still sends somewhere real.
    /// </summary>
    private string BuildResetLink(string token)
    {
        var baseUrl = _options.ResetPasswordUrl;

        if (string.IsNullOrWhiteSpace(baseUrl) && !string.IsNullOrWhiteSpace(_options.PortalUrl))
        {
            var portal = _options.PortalUrl!.Trim();
            var cut = portal.LastIndexOf('/');
            baseUrl = cut > "https://".Length ? portal[..cut] + "/reset-password" : portal;
        }

        // Nothing configured at all: a relative path is still something the reader can paste
        // behind their own host, and it beats emitting "?token=..." on its own.
        baseUrl = string.IsNullOrWhiteSpace(baseUrl) ? "/reset-password" : baseUrl!.Trim();

        var separator = baseUrl.Contains('?') ? '&' : '?';
        return $"{baseUrl}{separator}token={Uri.EscapeDataString(token)}";
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
        // The holder proved control of their own mailbox and chose this password, so it counts
        // as theirs and the flag clears.
        await _users.UpdatePasswordAsync(row.userId, _hasher.Hash(dto.NewPassword), false, ct);
        await _users.MarkResetTokenUsedAsync(dto.Token.Trim(), ct);
    }

    /// <summary>
    /// Refuses sign-in for a tenant that has been shut off. Judged on the stored statuses only,
    /// never on <c>end_date</c>: nothing advances a lapsed subscription to 'expired' yet, so
    /// dating the check would lock out every school whose seeded period has simply run out.
    /// </summary>
    /// <summary>
    /// School status and subscription both gate the login. This used to test the
    /// stored subscription status alone, which never changes on its own — so a
    /// trial that ran out months ago still read "trial" and its users kept
    /// signing in. The guard decides from the end date instead.
    /// </summary>
    private Task EnsureTenantIsUsableAsync(long schoolId, CancellationToken ct)
        => _entitlements.EnsureUsableAsync(schoolId, ct);

    private static void ValidateNewPassword(string pw)
    {
        if (string.IsNullOrWhiteSpace(pw) || pw.Length < 6)
            throw new ValidationException("New password must be at least 6 characters.");
    }

    private static AuthUserDto ToAuthUser(User u, string token, DateTime expiresAt, string theme)
    {
        var (role, portal, title) = MapRole(u);
        return new AuthUserDto(u.Id, u.SchoolId, u.UserType, role, u.Username, u.Email, u.FullName,
            portal, title, token, expiresAt, theme, u.MustChangePassword);
    }

    private static (string role, string portal, string title) MapRole(User u) => u.UserType switch
    {
        "super_admin" => ("super_admin", "/super-admin", "Platform Owner"),
        "school_admin" => ("school_admin", "/admin", "Administrator"),
        "teacher" => ("teacher", "/teacher", "Teacher"),
        "student" => ("student", "/student", "Student"),
        "parent" => ("parent", "/parent", "Parent"),
        _ => (u.UserType, "/login", u.UserType),
    };
}
