namespace SchoolErp.Application.Interfaces.Services;

/// <summary>Abstraction for outbound email/SMS. Implemented in Infrastructure.</summary>
public interface INotificationSender
{
    Task SendEmailAsync(string toEmail, string subject, string body, CancellationToken ct = default);
}
