namespace SchoolErp.Application.Interfaces.Services;

/// <summary>Abstraction for outbound email/SMS. Implemented in Infrastructure.</summary>
public interface INotificationSender
{
    Task SendEmailAsync(string toEmail, string subject, string body, CancellationToken ct = default);

    /// <summary>
    /// Sends both parts of the same message, letting the reader's client pick. The default
    /// implementation drops to plain text, so an implementation that cannot do HTML — the
    /// logging stub, or anything added later — needs no change and still delivers something
    /// readable.
    /// </summary>
    Task SendEmailAsync(string toEmail, string subject, string htmlBody, string plainBody,
        CancellationToken ct = default)
        => SendEmailAsync(toEmail, subject, plainBody, ct);
}
