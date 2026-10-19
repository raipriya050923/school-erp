using SchoolErp.Application.DTOs.Messaging;

namespace SchoolErp.Application.Interfaces.Services;

public interface IMessageTemplateService
{
    /* platform — writes the library every school inherits */
    Task<IReadOnlyList<TemplateDto>> ListPlatformAsync(string? channel, CancellationToken ct = default);
    Task<long> CreateAsync(SaveTemplateDto dto, CancellationToken ct = default);
    Task UpdatePlatformAsync(long id, SaveTemplateDto dto, CancellationToken ct = default);
    Task DeletePlatformAsync(long id, CancellationToken ct = default);

    /* school — sees every message that goes out in its name, overrides where allowed */
    Task<IReadOnlyList<SchoolTemplateDto>> ListForSchoolAsync(CancellationToken ct = default);
    Task SaveSchoolOverrideAsync(string channel, string code, string locale,
        SaveSchoolTemplateDto dto, CancellationToken ct = default);
    Task ClearSchoolOverrideAsync(string channel, string code, string locale,
        CancellationToken ct = default);

    TemplatePreviewDto Preview(string? subject, string body, IDictionary<string, string?> values);
}
