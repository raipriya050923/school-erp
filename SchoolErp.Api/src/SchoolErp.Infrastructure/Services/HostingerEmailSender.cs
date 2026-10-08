using Microsoft.Extensions.Logging;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Sends over Hostinger's SMTP rather than the one <see cref="INotificationSender"/> is wired to.
///
/// It owns no sending logic of its own: it hands its own options to <see cref="SmtpEmailSender"/>,
/// which already does the right thing with SSL-on-connect, STARTTLS and certificate revocation.
/// Duplicating that would mean two implementations drifting apart, and the first symptom would be
/// one provider mysteriously failing a handshake the other survives.
///
/// Deliberately not registered as INotificationSender: password resets and invoice mail keep
/// going out through the configured default, and this is resolved explicitly by the endpoints
/// that want Hostinger. Swapping the whole application over is a one-line change in
/// DependencyInjection, made on purpose rather than by accident of registration order.
/// </summary>
public class HostingerEmailSender
{
    private readonly SmtpEmailSender _smtp;
    public HostingerEmailOptions Options { get; }

    public HostingerEmailSender(HostingerEmailOptions options, ILogger<SmtpEmailSender> logger)
    {
        Options = options;
        _smtp = new SmtpEmailSender(options, logger);
    }

    public Task SendEmailAsync(string toEmail, string subject, string body, CancellationToken ct = default)
        => _smtp.SendEmailAsync(toEmail, subject, body, ct);

    /// <summary>Sends an HTML or plain-text body. Exceptions propagate, so a test can report why.</summary>
    public Task SendAsync(string toEmail, string subject, string body, bool isHtml, CancellationToken ct = default)
        => _smtp.SendAsync(toEmail, subject, body, isHtml, ct);
}
