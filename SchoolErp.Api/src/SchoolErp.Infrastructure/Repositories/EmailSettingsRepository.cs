using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

/// <summary>
/// The single settings row. Reads give the console everything except the password; writes take
/// a password only when one was typed.
/// </summary>
public class EmailSettingsRepository : IEmailSettingsRepository
{
    private readonly IDbConnectionFactory _factory;
    public EmailSettingsRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<EmailSettingsDto?> GetAsync(CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            @"SELECT provider, smtp_host, smtp_port, use_ssl, use_start_tls, user_name,
                     sender_email, sender_name, test_recipient,
                     (password_encrypted IS NOT NULL AND password_encrypted <> '') AS has_password,
                     graph_tenant_id, graph_client_id, graph_from_address, graph_from_name,
                     (graph_client_secret_encrypted IS NOT NULL
                      AND graph_client_secret_encrypted <> '') AS has_graph_secret,
                     updated_at
              FROM email_settings WHERE id = 1",
            r => new EmailSettingsDto(
                r.GetStringOrNull("provider") ?? "smtp",
                r.GetStringOrNull("smtp_host"),
                r.GetInt("smtp_port"),
                r.GetBool("use_ssl"),
                r.GetBool("use_start_tls"),
                r.GetStringOrNull("user_name"),
                r.GetStringOrNull("sender_email"),
                r.GetStringOrNull("sender_name"),
                r.GetStringOrNull("test_recipient"),
                r.GetBool("has_password"),
                r.GetStringOrNull("graph_tenant_id"),
                r.GetStringOrNull("graph_client_id"),
                r.GetStringOrNull("graph_from_address"),
                r.GetStringOrNull("graph_from_name"),
                r.GetBool("has_graph_secret"),
                r.GetDateOrNull("updated_at"),
                // Filled in by the service, which knows what the fallback holds.
                UsingFallback: false),
            ct);
    }

    /// <summary>
    /// Upserts the row. <paramref name="passwordCipher"/> null leaves the stored one alone, so
    /// editing the sender name does not blank the password the console never had.
    /// </summary>
    public async Task SaveAsync(
        SaveEmailSettingsDto dto, string? passwordCipher, string? graphSecretCipher,
        long? updatedBy, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Both providers are written every time. The one not in use keeps its settings, which
        // is what makes switching back a single change rather than a re-entry.
        await DbHelper.ExecuteAsync(conn,
            @"INSERT INTO email_settings
                (id, provider, smtp_host, smtp_port, use_ssl, use_start_tls, user_name,
                 sender_email, sender_name, test_recipient, password_encrypted,
                 graph_tenant_id, graph_client_id, graph_client_secret_encrypted,
                 graph_from_address, graph_from_name, updated_by)
              VALUES
                (1, @provider, @host, @port, @ssl, @tls, @user, @from, @fromName, @test, @pwd,
                 @gTenant, @gClient, @gSecret, @gFrom, @gFromName, @by)
              ON DUPLICATE KEY UPDATE
                provider = @provider,
                smtp_host = @host, smtp_port = @port, use_ssl = @ssl, use_start_tls = @tls,
                user_name = @user, sender_email = @from, sender_name = @fromName,
                test_recipient = @test,
                password_encrypted = COALESCE(@pwd, password_encrypted),
                graph_tenant_id = @gTenant, graph_client_id = @gClient,
                graph_client_secret_encrypted = COALESCE(@gSecret, graph_client_secret_encrypted),
                graph_from_address = @gFrom, graph_from_name = @gFromName,
                updated_by = @by",
            ct,
            ("@provider", string.Equals(dto.Provider, "graph", StringComparison.OrdinalIgnoreCase)
                ? "graph" : "smtp"),
            ("@host", (object?)Trim(dto.SmtpHost) ?? DBNull.Value),
            ("@port", dto.SmtpPort),
            ("@ssl", dto.UseSsl),
            ("@tls", dto.UseStartTls),
            ("@user", (object?)Trim(dto.UserName) ?? DBNull.Value),
            ("@from", (object?)Trim(dto.SenderEmail) ?? DBNull.Value),
            ("@fromName", (object?)Trim(dto.SenderName) ?? DBNull.Value),
            ("@test", (object?)Trim(dto.TestRecipient) ?? DBNull.Value),
            ("@pwd", (object?)passwordCipher ?? DBNull.Value),
            ("@gTenant", (object?)Trim(dto.GraphTenantId) ?? DBNull.Value),
            ("@gClient", (object?)Trim(dto.GraphClientId) ?? DBNull.Value),
            ("@gSecret", (object?)graphSecretCipher ?? DBNull.Value),
            ("@gFrom", (object?)Trim(dto.GraphFromAddress) ?? DBNull.Value),
            ("@gFromName", (object?)Trim(dto.GraphFromName) ?? DBNull.Value),
            ("@by", (object?)updatedBy ?? DBNull.Value));
    }

    private static string? Trim(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
}
