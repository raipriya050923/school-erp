using System.Diagnostics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Infrastructure.Services;

namespace SchoolErp.Api.Controllers;

/// <summary>A message to send through Hostinger. Every field is optional.</summary>
public class SendHostingerEmailDto
{
    /// <summary>
    /// Where to send it. Omit it — or leave Swagger's placeholder in place — to use
    /// HostingerEmailSettings:TestRecipient.
    /// </summary>
    public string? To { get; set; }
    public string? Subject { get; set; }
    public string? Body { get; set; }
    /// <summary>Send the body as HTML. Plain text when false or absent.</summary>
    public bool IsHtml { get; set; }
}

/// <summary>
/// Proves the mail configuration works, end to end, without waiting for a password reset or a
/// registration to go out.
///
/// It reads the same settings the application sends through, so a message that leaves here is
/// evidence about the real path rather than about a separate test rig.
///
/// Both actions are [AllowAnonymous] so they can be called without first obtaining a token. That
/// makes this a sending endpoint reachable by anyone who can reach the API — keep it off the
/// public internet, or put the [Authorize] back before this is exposed.
/// </summary>
[ApiController]
[Route("api/super-admin/email/hostinger")]
[Authorize(Roles = "super_admin")]
public class HostingerEmailController : ControllerBase
{
    private readonly HostingerEmailSender _sender;
    private readonly ILogger<HostingerEmailController> _logger;

    public HostingerEmailController(HostingerEmailSender sender, ILogger<HostingerEmailController> logger)
    {
        _sender = sender;
        _logger = logger;
    }

    /// <summary>
    /// What this provider is configured to do, without sending anything. The password is reported
    /// only as present or absent — a diagnostic must never hand back a credential.
    /// </summary>
    [AllowAnonymous]
    [HttpGet("config")]
    public IActionResult Config()
    {
        var o = _sender.Options;
        return Ok(new
        {
            provider = "hostinger",
            configured = o.IsConfigured,
            host = o.SmtpHost,
            port = o.SmtpPort,
            useSsl = o.UseSsl,
            useStartTls = o.UseStartTls,
            senderEmail = o.SenderEmail,
            senderName = o.SenderName,
            userName = string.IsNullOrWhiteSpace(o.UserName) ? o.SenderEmail : o.UserName,
            passwordSet = !string.IsNullOrWhiteSpace(o.Password),
            testRecipient = o.TestRecipient,
            // Hostinger advertises both; saying which one is actually in force stops the usual
            // "I set port 465 but it is still doing STARTTLS" dead end.
            transport = o.UseSsl ? "SSL on connect (port 465)"
                : o.UseStartTls ? "STARTTLS (port 587)"
                : "automatic — the server's advertisement decides",
        });
    }

    /// <summary>
    /// Sends one message through Hostinger and reports exactly what happened.
    ///
    /// Unlike the rest of the API this returns the underlying error rather than a generic
    /// failure: the entire purpose is to surface why the mail server said no.
    /// </summary>
    [AllowAnonymous]
    [HttpPost("test")]
    public async Task<IActionResult> SendTest([FromBody] SendHostingerEmailDto? dto, CancellationToken ct)
    {
        var o = _sender.Options;

        // A value with no "@" is taken as Swagger's placeholder rather than as an address, so
        // pressing Try it out on the unedited example sends somewhere real.
        var to = (dto?.To ?? string.Empty).Trim();
        if (to.Length == 0 || !to.Contains('@')) to = o.TestRecipient.Trim();
        if (to.Length == 0)
            return BadRequest(new
            {
                error = "validation_error",
                message = "Give an address to send to, or set HostingerEmailSettings:TestRecipient.",
            });

        if (!o.IsConfigured)
            return BadRequest(new
            {
                error = "not_configured",
                message = "Set HostingerEmailSettings:SmtpHost and HostingerEmailSettings:SenderEmail.",
            });

        // Hostinger requires authentication on every send. The shared sender skips the login
        // when the password is blank — correct for an internal relay that accepts mail from a
        // trusted host, wrong here — and the server then refuses the unauthenticated client with
        // "5.7.1 Client host rejected: Access denied". That message describes the symptom and
        // not the cause, so the cause is caught here instead of being guessed from it.
        if (string.IsNullOrWhiteSpace(o.Password))
            return BadRequest(new
            {
                error = "no_password",
                provider = "hostinger",
                message = $"No password is set for {(string.IsNullOrWhiteSpace(o.UserName) ? o.SenderEmail : o.UserName)}. " +
                          "Hostinger requires authentication, so the send would be refused. " +
                          "Set HostingerEmailSettings:Password to that mailbox's own password from hPanel, under Emails.",
            });

        var subject = string.IsNullOrWhiteSpace(dto?.Subject)
            ? $"Test email from {o.SenderName}"
            : dto!.Subject!.Trim();
        var body = string.IsNullOrWhiteSpace(dto?.Body)
            ? $"This is a test message sent from {o.SenderEmail} via {o.SmtpHost} at {DateTime.UtcNow:u}.\n\n" +
              "If you are reading it, outbound mail through Hostinger is working."
            : dto!.Body!;

        var sw = Stopwatch.StartNew();
        try
        {
            await _sender.SendAsync(to, subject, body, dto?.IsHtml ?? false, ct);
            sw.Stop();
            return Ok(new
            {
                sent = true,
                provider = "hostinger",
                to,
                from = o.SenderEmail,
                host = o.SmtpHost,
                port = o.SmtpPort,
                elapsedMs = sw.ElapsedMilliseconds,
                message = $"Sent to {to}. Check the inbox, and the spam folder.",
            });
        }
        catch (Exception ex)
        {
            sw.Stop();
            _logger.LogError(ex, "Hostinger test email to {To} failed", to);
            // 502: the request was fine, the mail server refused it.
            return StatusCode(StatusCodes.Status502BadGateway, new
            {
                sent = false,
                provider = "hostinger",
                to,
                host = o.SmtpHost,
                port = o.SmtpPort,
                elapsedMs = sw.ElapsedMilliseconds,
                error = ex.GetType().Name,
                message = ex.Message,
                // The cause is usually one level down — MailKit wraps the server's own refusal.
                inner = ex.InnerException?.Message,
                hint = Hint(ex),
            });
        }
    }

    /// <summary>Turns the failures that actually happen with Hostinger into the thing to check.</summary>
    private string? Hint(Exception ex)
    {
        var o = _sender.Options;
        var text = $"{ex.Message} {ex.InnerException?.Message}".ToLowerInvariant();

        if (text.Contains("authentic") || text.Contains("535") || text.Contains("credential"))
            return $"The server rejected the login. On Hostinger the username is the complete mailbox " +
                   $"address ({(string.IsNullOrWhiteSpace(o.UserName) ? o.SenderEmail : o.UserName)}) and the " +
                   "password is that mailbox's own password — set in hPanel under Emails, not an " +
                   "application-specific password. Check the mailbox exists and the password is current.";
        if (text.Contains("timed out") || text.Contains("timeout") || text.Contains("unreachable")
            || text.Contains("refused") || text.Contains("no such host"))
            return $"Could not reach {o.SmtpHost}:{o.SmtpPort}. Check the host name, and that outbound " +
                   "SMTP is not blocked from this machine — many home and office networks block 465 and 587.";
        // Checked before the general TLS case: the settings are right, the machine just could not
        // reach the CA to check revocation, and "fix your ports" would send you the wrong way.
        if (text.Contains("revocation"))
            return "The certificate is fine — this machine could not reach the CA to check whether it " +
                   "was revoked. SmtpEmailSender disables that lookup; if you still see this, the API " +
                   "is running older code than the source.";
        if (text.Contains("ssl") || text.Contains("tls") || text.Contains("handshake"))
            return "TLS negotiation failed. Hostinger wants port 465 with UseSsl=true, or port 587 with " +
                   $"UseStartTls=true. You currently have port {o.SmtpPort} with UseSsl={o.UseSsl} and " +
                   $"UseStartTls={o.UseStartTls} — those have to agree.";
        // Hostinger's wording for "you have not logged in", which reads like a network problem.
        if (text.Contains("client host rejected") || text.Contains("access denied") || text.Contains("5.7.1"))
            return "The server accepted the connection but refused to relay, which is what it says when " +
                   "the session never authenticated. Check HostingerEmailSettings:Password is set and " +
                   "correct for " + (string.IsNullOrWhiteSpace(o.UserName) ? o.SenderEmail : o.UserName) + ".";
        if (text.Contains("relay") || text.Contains("not allowed") || text.Contains("sender"))
            return $"The server would not send as {o.SenderEmail}. On Hostinger the From address has to be " +
                   "the same mailbox you authenticated as.";
        return null;
    }
}
