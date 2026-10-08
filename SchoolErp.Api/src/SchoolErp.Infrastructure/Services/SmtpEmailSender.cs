using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using MimeKit;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Sends real mail over SMTP. Registered in place of the logging stub whenever
/// "EmailSettings:SmtpHost" is set, so an unconfigured environment still runs.
/// </summary>
public class SmtpEmailSender : INotificationSender
{
    private readonly EmailOptions _options;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(EmailOptions options, ILogger<SmtpEmailSender> logger)
    {
        _options = options;
        _logger = logger;
    }

    public Task SendEmailAsync(string toEmail, string subject, string body, CancellationToken ct = default)
        => SendAsync(toEmail, subject, body, isHtml: false, ct);

    /// <summary>
    /// Sends one message carrying both renderings. multipart/alternative rather than HTML alone:
    /// a client that will not render HTML shows the plain part instead of an empty message, and
    /// some spam filters treat an HTML-only mail with no text alternative as a mark against it.
    /// </summary>
    public async Task SendEmailAsync(string toEmail, string subject, string htmlBody, string plainBody,
        CancellationToken ct = default)
    {
        var body = new MultipartAlternative
        {
            // Order matters: least preferred first, so the client takes the HTML when it can.
            new TextPart(MimeKit.Text.TextFormat.Plain) { Text = plainBody },
            new TextPart(MimeKit.Text.TextFormat.Html) { Text = htmlBody },
        };
        await SendBodyAsync(toEmail, subject, body, ct);
    }

    /// <summary>
    /// The one place a message is actually handed to the server. Exceptions are left to
    /// propagate: a caller that wants failures to be non-fatal is the one that should decide
    /// that, and the test endpoint needs the real reason to be of any use.
    /// </summary>
    public Task SendAsync(string toEmail, string subject, string body, bool isHtml,
        CancellationToken ct = default)
        => SendBodyAsync(toEmail, subject,
            new TextPart(isHtml ? MimeKit.Text.TextFormat.Html : MimeKit.Text.TextFormat.Plain) { Text = body },
            ct);

    /// <summary>
    /// Addresses the message and hands it to the server. Everything above differs only in how the
    /// body was built, so the connection, TLS and authentication live here once.
    /// </summary>
    private async Task SendBodyAsync(string toEmail, string subject, MimeEntity body, CancellationToken ct)
    {
        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_options.SenderName, _options.SenderEmail));
        message.To.Add(MailboxAddress.Parse(toEmail));
        message.Subject = subject;
        message.Body = body;

        using var client = new SmtpClient();

        // Windows refuses the handshake when it cannot reach the CA to ask whether the server's
        // certificate has been revoked — "the revocation function was unable to check revocation",
        // which is a failure to ASK, not a bad certificate. Common on machines with restricted
        // outbound access. Only the revocation lookup is skipped: the chain, the expiry and the
        // host name are all still verified, unlike a callback that returns true for everything.
        client.CheckCertificateRevocation = false;

        // Explicit SSL on 465, STARTTLS on 587, and Auto when neither is stated — the provider's
        // own advertisement is more reliable than guessing from the port number.
        var security = _options.UseSsl ? SecureSocketOptions.SslOnConnect
            : _options.UseStartTls ? SecureSocketOptions.StartTls
            : SecureSocketOptions.Auto;

        await client.ConnectAsync(_options.SmtpHost, _options.SmtpPort, security, ct);

        // An empty password means the relay takes unauthenticated mail from this host — common
        // for an internal relay, and AuthenticateAsync with blank credentials would fail on it.
        if (!string.IsNullOrWhiteSpace(_options.Password))
        {
            var user = string.IsNullOrWhiteSpace(_options.UserName) ? _options.SenderEmail : _options.UserName;
            await client.AuthenticateAsync(user, _options.Password, ct);
        }

        await client.SendAsync(message, ct);
        await client.DisconnectAsync(true, ct);

        _logger.LogInformation("Email sent to {To} via {Host} | {Subject}", toEmail, _options.SmtpHost, subject);
    }
}
