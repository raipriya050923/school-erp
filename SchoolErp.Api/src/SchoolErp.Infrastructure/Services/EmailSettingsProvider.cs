using System.Data;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Logging;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Reads the console's mail settings, falling back to appsettings.json.
///
/// Registered as a singleton holding one cached copy: mail settings change about once a year
/// and are read on every message sent, so a query per send would be the wrong way round.
/// <see cref="Invalidate"/> drops the copy when the console writes.
/// </summary>
public class EmailSettingsProvider : IEmailSettingsProvider
{
    private readonly IDbConnectionFactory _factory;
    private readonly EmailOptions _fallback;
    private readonly IDataProtector _protector;
    private readonly ILogger<EmailSettingsProvider> _logger;

    private readonly SemaphoreSlim _gate = new(1, 1);
    private MailSettings? _cached;

    public EmailSettingsProvider(
        IDbConnectionFactory factory,
        EmailOptions fallback,
        IDataProtectionProvider protection,
        ILogger<EmailSettingsProvider> logger)
    {
        _factory = factory;
        _fallback = fallback;
        // The purpose string is part of the key: ciphertext from this protector cannot be
        // unprotected by any other, so a bug elsewhere cannot read the mailbox password.
        _protector = protection.CreateProtector("SchoolErp.EmailSettings.v1");
        _logger = logger;
    }

    public void Invalidate() => _cached = null;

    /// <summary>The SMTP half, for the sender that wants nothing else.</summary>
    public async Task<EmailOptions> GetAsync(CancellationToken ct = default)
        => (await GetMailSettingsAsync(ct)).Smtp;

    public async Task<MailSettings> GetMailSettingsAsync(CancellationToken ct = default)
    {
        if (_cached is not null) return _cached;

        await _gate.WaitAsync(ct);
        try
        {
            if (_cached is not null) return _cached;
            _cached = await LoadAsync(ct);
            return _cached;
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task<MailSettings> LoadAsync(CancellationToken ct)
    {
        try
        {
            using var conn = await _factory.CreateOpenConnectionAsync(ct);
            var row = await DbHelper.QuerySingleAsync(conn,
                @"SELECT provider, smtp_host, smtp_port, use_ssl, use_start_tls, user_name,
                         sender_email, sender_name, test_recipient, password_encrypted,
                         graph_tenant_id, graph_client_id, graph_client_secret_encrypted,
                         graph_from_address, graph_from_name
                  FROM email_settings WHERE id = 1",
                MapSettings, ct);

            if (row is null) return Fallback();

            // A row whose live provider is not configured is the unconfigured state, not a
            // configured-to-nothing one, so the file still wins.
            var usable = row.UsesGraph
                ? row.Graph.IsConfigured
                : !string.IsNullOrWhiteSpace(row.Smtp.SmtpHost);
            return usable ? row : Fallback();
        }
        catch (Exception ex)
        {
            // Mail settings must never be the reason the application will not start or a
            // request fails. If the columns are missing — an environment that has not run
            // migration 024 or 025 — carry on with the file.
            _logger.LogWarning(ex, "Could not read email_settings; using appsettings.json.");
            return Fallback();
        }
    }

    /// <summary>appsettings.json knows only SMTP, so the fallback is always the SMTP route.</summary>
    private MailSettings Fallback() => new() { Provider = "smtp", Smtp = _fallback };

    private MailSettings MapSettings(IDataRecord r) => new()
    {
        Provider = r.GetStringOrNull("provider") ?? "smtp",
        Smtp = Map(r),
        Graph = new GraphMailOptions
        {
            TenantId = r.GetStringOrNull("graph_tenant_id") ?? string.Empty,
            ClientId = r.GetStringOrNull("graph_client_id") ?? string.Empty,
            ClientSecret = Unprotect(r.GetStringOrNull("graph_client_secret_encrypted")),
            FromAddress = r.GetStringOrNull("graph_from_address") ?? string.Empty,
            FromName = r.GetStringOrNull("graph_from_name") ?? string.Empty,
        },
    };

    private EmailOptions Map(IDataRecord r) => new()
    {
        SmtpHost = r.GetStringOrNull("smtp_host") ?? string.Empty,
        SmtpPort = r.GetInt("smtp_port"),
        UseSsl = r.GetBool("use_ssl"),
        UseStartTls = r.GetBool("use_start_tls"),
        UserName = r.GetStringOrNull("user_name"),
        SenderEmail = r.GetStringOrNull("sender_email") ?? string.Empty,
        SenderName = r.GetStringOrNull("sender_name") ?? string.Empty,
        TestRecipient = r.GetStringOrNull("test_recipient") ?? string.Empty,
        Password = Unprotect(r.GetStringOrNull("password_encrypted")),
    };

    private string Unprotect(string? cipher)
    {
        if (string.IsNullOrEmpty(cipher)) return string.Empty;
        try
        {
            return _protector.Unprotect(cipher);
        }
        catch (Exception ex)
        {
            // Data Protection keys live with the deployment. Moving the database to a machine
            // without them leaves ciphertext nobody can read — which must surface as "mail is
            // not authenticating", not as a crash on the first send.
            _logger.LogError(ex,
                "A stored mail secret could not be decrypted. It was saved under different " +
                "Data Protection keys; set it again in the console.");
            return string.Empty;
        }
    }

    /// <summary>Encrypts a password for storage. Used by the write path.</summary>
    public string Protect(string plaintext) => _protector.Protect(plaintext);
}
