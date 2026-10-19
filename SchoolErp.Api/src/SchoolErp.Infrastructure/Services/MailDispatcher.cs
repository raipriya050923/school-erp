using Microsoft.Extensions.Logging;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// The one <see cref="INotificationSender"/> everything else injects. It holds no transport of
/// its own: it reads which provider is live and hands the message to that one.
///
/// Chosen per message rather than per process, so switching provider in the console takes
/// effect on the next send — which is the point of having two. Nothing that sends mail knows
/// or cares which is in use.
/// </summary>
public class MailDispatcher : INotificationSender
{
    private readonly IEmailSettingsProvider _settings;
    private readonly SmtpEmailSender _smtp;
    private readonly GraphEmailSender _graph;
    private readonly ILogger<MailDispatcher> _logger;

    public MailDispatcher(
        IEmailSettingsProvider settings,
        SmtpEmailSender smtp,
        GraphEmailSender graph,
        ILogger<MailDispatcher> logger)
    {
        _settings = settings;
        _smtp = smtp;
        _graph = graph;
        _logger = logger;
    }

    public async Task SendEmailAsync(string toEmail, string subject, string body,
        CancellationToken ct = default)
    {
        var sender = await ChooseAsync(ct);
        await sender.SendEmailAsync(toEmail, subject, body, ct);
    }

    public async Task SendEmailAsync(string toEmail, string subject, string htmlBody,
        string plainBody, CancellationToken ct = default)
    {
        var sender = await ChooseAsync(ct);
        await sender.SendEmailAsync(toEmail, subject, htmlBody, plainBody, ct);
    }

    private async Task<INotificationSender> ChooseAsync(CancellationToken ct)
    {
        var settings = await _settings.GetMailSettingsAsync(ct);

        if (settings.UsesGraph)
        {
            // Selected but half-configured is worth saying plainly rather than falling back:
            // mail silently leaving by the other route is how a sender address nobody expected
            // ends up on a parent's phone.
            if (!settings.Graph.IsConfigured)
                _logger.LogWarning(
                    "Microsoft Graph is selected but incomplete; the send will fail rather than " +
                    "quietly going out over SMTP.");
            return _graph;
        }

        return _smtp;
    }
}
