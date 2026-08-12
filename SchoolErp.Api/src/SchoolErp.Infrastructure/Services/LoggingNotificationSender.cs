using Microsoft.Extensions.Logging;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Stub notification sender that logs instead of sending. Swap for an SMTP/SendGrid
/// implementation later — the Application layer depends only on INotificationSender.
/// </summary>
public class LoggingNotificationSender : INotificationSender
{
    private readonly ILogger<LoggingNotificationSender> _logger;
    public LoggingNotificationSender(ILogger<LoggingNotificationSender> logger) => _logger = logger;

    public Task SendEmailAsync(string toEmail, string subject, string body, CancellationToken ct = default)
    {
        _logger.LogInformation("EMAIL → {To} | {Subject}\n{Body}", toEmail, subject, body);
        return Task.CompletedTask;
    }
}
