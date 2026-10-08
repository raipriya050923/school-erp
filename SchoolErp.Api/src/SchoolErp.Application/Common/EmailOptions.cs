namespace SchoolErp.Application.Common;

/// <summary>
/// Outbound mail settings, bound from the "HostingerEmailSettings" configuration section.
/// (Bound from "HostingerEmailSettings"; see DependencyInjection, which
/// no longer sends through.)
///
/// With <see cref="SmtpHost"/> empty the application keeps its logging stub, so a developer
/// with no mail server still gets a working build and sees every message in the console.
/// </summary>
public class EmailOptions
{
    public string SmtpHost { get; set; } = string.Empty;
    public int SmtpPort { get; set; } = 465;
    public bool UseSsl { get; set; } = true;
    public bool UseStartTls { get; set; }

    /// <summary>The From address, and — for most hosted providers — the login as well.</summary>
    public string SenderEmail { get; set; } = string.Empty;
    public string SenderName { get; set; } = string.Empty;

    /// <summary>
    /// Mailbox password or app-specific password. Never commit a real one: set it per
    /// environment, through appsettings.Development.json, an environment variable
    /// (EmailSettings__Password) or the deployment's secret store.
    /// </summary>
    public string Password { get; set; } = string.Empty;

    /// <summary>
    /// A username that differs from the From address. Left empty, <see cref="SenderEmail"/> is
    /// used — which is what most hosted providers expect.
    /// </summary>
    public string? UserName { get; set; }

    /// <summary>
    /// Where the test endpoint sends when the caller names no recipient, so checking that mail
    /// works is a request with no body. A caller that does supply an address still wins.
    /// </summary>
    public string TestRecipient { get; set; } = string.Empty;

    /// <summary>Whether enough is configured to attempt a real send.</summary>
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(SmtpHost) && !string.IsNullOrWhiteSpace(SenderEmail);
}
