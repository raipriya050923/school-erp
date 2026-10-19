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
        var unconfigured = row is null
            || (row.Provider == "graph"
                ? string.IsNullOrWhiteSpace(row.GraphTenantId)
                : string.IsNullOrWhiteSpace(row.SmtpHost));
        if (unconfigured)
        {
            return Ok(new EmailSettingsDto(
                // The file configures SMTP only, so that is what a fallback deployment is on.
                Provider: "smtp",
                _fallback.SmtpHost, _fallback.SmtpPort, _fallback.UseSsl, _fallback.UseStartTls,
                _fallback.UserName, _fallback.SenderEmail, _fallback.SenderName,
                _fallback.TestRecipient,
                HasPassword: !string.IsNullOrEmpty(_fallback.Password),
                GraphTenantId: null,
                GraphClientId: null,
                GraphFromAddress: null,
                GraphFromName: null,
                HasGraphSecret: false,
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
        var usesGraph = string.Equals(dto.Provider, "graph", StringComparison.OrdinalIgnoreCase);
        if (!usesGraph && !string.Equals(dto.Provider, "smtp", StringComparison.OrdinalIgnoreCase))
            throw new ValidationException("The provider must be either smtp or graph.");

        // Only the live provider is validated. The other half is still saved, so a half-filled
        // SMTP section cannot block a switch to Graph — and switching back finds it intact.
        if (usesGraph)
        {
            if (string.IsNullOrWhiteSpace(dto.GraphTenantId))
                throw new ValidationException("A directory (tenant) ID is required.");
            if (string.IsNullOrWhiteSpace(dto.GraphClientId))
                throw new ValidationException("An application (client) ID is required.");
            if (string.IsNullOrWhiteSpace(dto.GraphFromAddress))
                throw new ValidationException(
                    "A sender mailbox is required — Graph sends as that mailbox, not as whoever authenticated.");

            // Saving Graph as live with no secret ever stored would leave mail unable to leave
            // with nothing on screen to say why.
            var stored = await _repo.GetAsync(ct);
            if (string.IsNullOrEmpty(dto.GraphClientSecret) && stored?.HasGraphSecret != true)
                throw new ValidationException(
                    "A client secret is required. Use the secret VALUE, not the secret ID.");
        }
        else
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
        }

        // Only encrypt what was typed; null means "leave the stored one". The same applies to
        // the Graph client secret, which the console never receives and so cannot send back.
        string? cipher = null;
        string? graphCipher = null;
        if (!string.IsNullOrEmpty(dto.Password) || !string.IsNullOrEmpty(dto.GraphClientSecret))
        {
            if (provider is not EmailSettingsProvider concrete)
                throw new ValidationException("This deployment cannot store a mail secret.");
            if (!string.IsNullOrEmpty(dto.Password)) cipher = concrete.Protect(dto.Password);
            if (!string.IsNullOrEmpty(dto.GraphClientSecret))
                graphCipher = concrete.Protect(dto.GraphClientSecret);
        }

        await _repo.SaveAsync(dto, cipher, graphCipher, _user.UserId, ct);
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
        var settings = await _provider.GetMailSettingsAsync(ct);
        var recipient = string.IsNullOrWhiteSpace(to) ? settings.Smtp.TestRecipient : to.Trim();

        // Named for what the message will actually leave by, so a test that succeeds says which
        // route succeeded.
        var via = settings.UsesGraph
            ? $"Microsoft Graph ({settings.Graph.FromAddress})"
            : settings.Smtp.SmtpHost;

        if (string.IsNullOrWhiteSpace(recipient))
            throw new ValidationException("Give an address to send to, or set a default test recipient.");
        if (settings.UsesGraph)
        {
            if (!settings.Graph.IsConfigured)
                throw new ValidationException("Finish the Microsoft Graph settings first.");
        }
        else if (string.IsNullOrWhiteSpace(settings.Smtp.SmtpHost))
        {
            throw new ValidationException("Set an SMTP host first.");
        }

        try
        {
            await _mail.SendEmailAsync(recipient,
                "Test message from Pathshala",
                "<p>Your outbound mail settings are working.</p>",
                "Your outbound mail settings are working.",
                ct);
            return Ok(new { sent = true, to = recipient, via });
        }
        catch (Exception ex)
        {
            // The provider's own words are worth far more than "sending failed" — an auth
            // rejection and a blocked port read very differently.
            return Ok(new { sent = false, to = recipient, via, error = ex.Message });
        }
    }
}
