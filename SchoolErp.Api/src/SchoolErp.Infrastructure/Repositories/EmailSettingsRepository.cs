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
            @"SELECT smtp_host, smtp_port, use_ssl, use_start_tls, user_name, sender_email,
                     sender_name, test_recipient,
                     (password_encrypted IS NOT NULL AND password_encrypted <> '') AS has_password,
                     updated_at
              FROM email_settings WHERE id = 1",
            r => new EmailSettingsDto(
                r.GetStringOrNull("smtp_host"),
                r.GetInt("smtp_port"),
                r.GetBool("use_ssl"),
                r.GetBool("use_start_tls"),
                r.GetStringOrNull("user_name"),
                r.GetStringOrNull("sender_email"),
                r.GetStringOrNull("sender_name"),
                r.GetStringOrNull("test_recipient"),
                r.GetBool("has_password"),
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
        SaveEmailSettingsDto dto, string? passwordCipher, long? updatedBy,
        CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"INSERT INTO email_settings
                (id, smtp_host, smtp_port, use_ssl, use_start_tls, user_name, sender_email,
                 sender_name, test_recipient, password_encrypted, updated_by)
              VALUES
                (1, @host, @port, @ssl, @tls, @user, @from, @fromName, @test, @pwd, @by)
              ON DUPLICATE KEY UPDATE
                smtp_host = @host, smtp_port = @port, use_ssl = @ssl, use_start_tls = @tls,
                user_name = @user, sender_email = @from, sender_name = @fromName,
                test_recipient = @test,
                password_encrypted = COALESCE(@pwd, password_encrypted),
                updated_by = @by",
            ct,
            ("@host", (object?)Trim(dto.SmtpHost) ?? DBNull.Value),
            ("@port", dto.SmtpPort),
            ("@ssl", dto.UseSsl),
            ("@tls", dto.UseStartTls),
            ("@user", (object?)Trim(dto.UserName) ?? DBNull.Value),
            ("@from", (object?)Trim(dto.SenderEmail) ?? DBNull.Value),
            ("@fromName", (object?)Trim(dto.SenderName) ?? DBNull.Value),
            ("@test", (object?)Trim(dto.TestRecipient) ?? DBNull.Value),
            ("@pwd", (object?)passwordCipher ?? DBNull.Value),
            ("@by", (object?)updatedBy ?? DBNull.Value));
    }

    private static string? Trim(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
}
