using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IEmailSettingsRepository
{
    /// <summary>The stored row, or null when migration 024 has not run.</summary>
    Task<EmailSettingsDto?> GetAsync(CancellationToken ct = default);

    /// <summary>
    /// Upserts the row. A null <paramref name="passwordCipher"/> leaves the stored password
    /// untouched — the console never receives it, so it cannot send it back.
    /// </summary>
    Task SaveAsync(SaveEmailSettingsDto dto, string? passwordCipher, long? updatedBy,
        CancellationToken ct = default);
}
