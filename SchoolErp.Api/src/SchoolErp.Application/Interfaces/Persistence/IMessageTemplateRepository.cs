using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IMessageTemplateRepository
{
    /// <summary>Every platform default, newest channel/code order.</summary>
    Task<IReadOnlyList<MessageTemplate>> GetPlatformAsync(string? channel, CancellationToken ct = default);

    Task<MessageTemplate?> GetByIdAsync(long id, CancellationToken ct = default);

    /// <summary>One platform default by its identity, or null when there is none.</summary>
    Task<MessageTemplate?> GetPlatformOneAsync(string channel, string code, string locale, CancellationToken ct = default);

    /// <summary>A school's override, or null when it inherits.</summary>
    Task<MessageTemplate?> GetSchoolOneAsync(long schoolId, string channel, string code, string locale, CancellationToken ct = default);

    /// <summary>Every override a school holds, for listing its messages alongside the defaults.</summary>
    Task<IReadOnlyList<MessageTemplate>> GetSchoolAsync(long schoolId, CancellationToken ct = default);

    /// <summary>How many schools have overridden each platform default, keyed by its id.</summary>
    Task<IReadOnlyDictionary<long, int>> GetOverrideCountsAsync(CancellationToken ct = default);

    Task<long> InsertAsync(MessageTemplate template, CancellationToken ct = default);
    Task UpdateAsync(MessageTemplate template, CancellationToken ct = default);
    Task DeleteAsync(long id, CancellationToken ct = default);
}
