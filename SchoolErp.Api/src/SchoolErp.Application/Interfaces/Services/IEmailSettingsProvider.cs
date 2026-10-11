using SchoolErp.Application.Common;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>
/// Where the mail settings come from at the moment of sending.
///
/// They used to be a singleton bound once at startup, which is why changing a mailbox meant a
/// redeploy. Resolving them per send is what lets the console change them; the implementation
/// caches, so this is not a query per message.
/// </summary>
public interface IEmailSettingsProvider
{
    /// <summary>
    /// The settings in force: the console's row when it has a host, otherwise whatever
    /// appsettings.json carried. An environment never touched through the console behaves
    /// exactly as it did before.
    /// </summary>
    Task<EmailOptions> GetAsync(CancellationToken ct = default);

    /// <summary>Called after a write, so the next send picks the new settings up.</summary>
    void Invalidate();
}

/// <summary>
/// Mail settings as the console reads and writes them.
///
/// <paramref name="HasPassword"/> rather than the password: the stored value is ciphertext and
/// the plaintext is never returned, so the console can say whether one is set and nothing more.
/// </summary>
public record EmailSettingsDto(
    string? SmtpHost,
    int SmtpPort,
    bool UseSsl,
    bool UseStartTls,
    string? UserName,
    string? SenderEmail,
    string? SenderName,
    string? TestRecipient,
    bool HasPassword,
    DateTime? UpdatedAt,
    /// <summary>True while the row is empty and appsettings.json is still in charge.</summary>
    bool UsingFallback);

public class SaveEmailSettingsDto
{
    public string? SmtpHost { get; set; }
    public int SmtpPort { get; set; } = 587;
    public bool UseSsl { get; set; }
    public bool UseStartTls { get; set; } = true;
    public string? UserName { get; set; }
    public string? SenderEmail { get; set; }
    public string? SenderName { get; set; }
    public string? TestRecipient { get; set; }

    /// <summary>
    /// Null leaves the stored password alone — the console does not have it to send back, so
    /// an edit that changes only the sender name must not blank it.
    /// </summary>
    public string? Password { get; set; }
}
