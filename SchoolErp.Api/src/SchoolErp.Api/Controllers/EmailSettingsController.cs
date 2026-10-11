using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Infrastructure.Services;

namespace SchoolErp.Api.Controllers;

/// <summary>
/// Outbound mail settings, as the platform owner sets them.
///
/// These were in appsettings.json, which meant a changed mailbox needed a redeploy and the
/// password lived in a tracked file. The password is encrypted here and never returned: the
/// console is told whether one is set, not what it is.
/// </summary>
[ApiController]
[Route("api/super-admin/email-settings")]
[Authorize(Roles = "super_admin")]
public class EmailSettingsController : ControllerBase
{
    private readonly IEmailSettingsRepository _repo;
    private readonly IEmailSettingsProvider _provider;
    private readonly EmailOptions _fallback;
    private readonly ICurrentUser _user;
    private readonly INotificationSender _mail;

    public EmailSettingsController(
        IEmailSettingsRepository repo,
        IEmailSettingsProvider provider,
        EmailOptions fallback,
        ICurrentUser user,
        INotificationSender mail)
    {
        _repo = repo;
        _provider = provider;
        _fallback = fallback;
        _user = user;
        _mail = mail;
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var row = await _repo.GetAsync(ct);

        // No row, or a row with no host, means appsettings.json is still in charge. Showing the
        // file's values rather than blanks is what stops someone "fixing" a working setup by
        // filling in a form that looked empty.
        if (row is null || string.IsNullOrWhiteSpace(row.SmtpHost))
        {
            return Ok(new EmailSettingsDto(
                _fallback.SmtpHost, _fallback.SmtpPort, _fallback.UseSsl, _fallback.UseStartTls,
                _fallback.UserName, _fallback.SenderEmail, _fallback.SenderName,
                _fallback.TestRecipient,
                HasPassword: !string.IsNullOrEmpty(_fallback.Password),
                UpdatedAt: null,
                UsingFallback: true));
        }

        return Ok(row);
    }

    [HttpPut]
    public async Task<IActionResult> Save(
        [FromBody] SaveEmailSettingsDto dto,
        [FromServices] IEmailSettingsProvider provider,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(dto.SmtpHost))
            throw new ValidationException("An SMTP host is required.");
        if (string.IsNullOrWhiteSpace(dto.SenderEmail))
            throw new ValidationException("A sender address is required — it is what recipients reply to.");
        if (dto.SmtpPort is < 1 or > 65535)
            throw new ValidationException("The port must be between 1 and 65535.");

        // 465 speaks TLS from the first byte; 587 opens in the clear and upgrades. Asking for
        // both, or neither, is a configuration that cannot connect — and the error it produces
        // ("connection reset", "handshake failed") says nothing about which.
        if (dto.UseSsl && dto.UseStartTls)
            throw new ValidationException(
                "Choose one of SSL on connect (usually port 465) or STARTTLS (usually 587), not both.");
        if (!dto.UseSsl && !dto.UseStartTls)
            throw new ValidationException(
                "Pick SSL on connect or STARTTLS. Sending credentials unencrypted is not offered.");

        // Only encrypt when something was typed; null means "leave the stored one".
        string? cipher = null;
        if (!string.IsNullOrEmpty(dto.Password))
        {
            if (provider is EmailSettingsProvider concrete)
                cipher = concrete.Protect(dto.Password);
            else
                throw new ValidationException("This deployment cannot store a mail password.");
        }

        await _repo.SaveAsync(dto, cipher, _user.UserId, ct);
        // Without this the next message would still use the settings loaded at startup.
        _provider.Invalidate();

        return NoContent();
    }

    /// <summary>
    /// Sends one message with the settings as they are now stored. The only way to know a
    /// mail configuration works is to have it deliver something.
    /// </summary>
    [HttpPost("test")]
    public async Task<IActionResult> Test([FromQuery] string? to, CancellationToken ct)
    {
        var settings = await _provider.GetAsync(ct);
        var recipient = string.IsNullOrWhiteSpace(to) ? settings.TestRecipient : to.Trim();

        if (string.IsNullOrWhiteSpace(recipient))
            throw new ValidationException("Give an address to send to, or set a default test recipient.");
        if (string.IsNullOrWhiteSpace(settings.SmtpHost))
            throw new ValidationException("Set an SMTP host first.");

        try
        {
            await _mail.SendEmailAsync(recipient,
                "Test message from Pathshala",
                "<p>Your outbound mail settings are working.</p>",
                "Your outbound mail settings are working.",
                ct);
            return Ok(new { sent = true, to = recipient, via = settings.SmtpHost });
        }
        catch (Exception ex)
        {
            // The provider's own words are worth far more than "sending failed" — an auth
            // rejection and a blocked port read very differently.
            return Ok(new { sent = false, to = recipient, via = settings.SmtpHost, error = ex.Message });
        }
    }
}
