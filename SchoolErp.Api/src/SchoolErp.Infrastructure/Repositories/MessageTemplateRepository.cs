using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class MessageTemplateRepository : IMessageTemplateRepository
{
    private readonly IDbConnectionFactory _factory;
    public MessageTemplateRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Columns =
        "id, school_id, channel, code, locale, subject, body, provider_template_id, " +
        "editable_by, is_active, created_at, updated_at";

    private static MessageTemplate Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLongOrNull("school_id"),
        Channel = r.GetString("channel"),
        Code = r.GetString("code"),
        Locale = r.GetString("locale"),
        Subject = r.GetStringOrNull("subject"),
        Body = r.GetString("body"),
        ProviderTemplateId = r.GetStringOrNull("provider_template_id"),
        EditableBy = r.GetString("editable_by"),
        IsActive = r.GetBool("is_active"),
        CreatedAt = r.GetDate("created_at"),
        UpdatedAt = r.GetDate("updated_at"),
    };

    public async Task<IReadOnlyList<MessageTemplate>> GetPlatformAsync(
        string? channel, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // An empty channel means every channel, so the same endpoint serves the combined list
        // and a per-channel tab without two queries.
        return await DbHelper.QueryAsync(conn,
            $@"SELECT {Columns} FROM message_templates
               WHERE school_id IS NULL AND (@ch = '' OR channel = @ch)
               ORDER BY channel, code, locale",
            Map, ct, ("@ch", channel ?? string.Empty));
    }

    public async Task<MessageTemplate?> GetByIdAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $"SELECT {Columns} FROM message_templates WHERE id=@id", Map, ct, ("@id", id));
    }

    public async Task<MessageTemplate?> GetPlatformOneAsync(
        string channel, string code, string locale, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $@"SELECT {Columns} FROM message_templates
               WHERE school_id IS NULL AND channel=@ch AND code=@code AND locale=@loc",
            Map, ct, ("@ch", channel), ("@code", code), ("@loc", locale));
    }

    public async Task<MessageTemplate?> GetSchoolOneAsync(
        long schoolId, string channel, string code, string locale, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $@"SELECT {Columns} FROM message_templates
               WHERE school_id=@sid AND channel=@ch AND code=@code AND locale=@loc",
            Map, ct, ("@sid", schoolId), ("@ch", channel), ("@code", code), ("@loc", locale));
    }

    public async Task<IReadOnlyList<MessageTemplate>> GetSchoolAsync(
        long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            $@"SELECT {Columns} FROM message_templates
               WHERE school_id=@sid ORDER BY channel, code, locale",
            Map, ct, ("@sid", schoolId));
    }

    public async Task<IReadOnlyDictionary<long, int>> GetOverrideCountsAsync(
        CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Overrides are matched to their default by identity rather than by a foreign key: a
        // school row and the platform row it replaces share a channel, code and locale, which
        // is the whole of what makes them the same message.
        var rows = await DbHelper.QueryAsync(conn,
            @"SELECT p.id AS platform_id, COUNT(s.id) AS overrides
              FROM message_templates p
              LEFT JOIN message_templates s
                ON s.school_id IS NOT NULL
               AND s.channel = p.channel AND s.code = p.code AND s.locale = p.locale
              WHERE p.school_id IS NULL
              GROUP BY p.id",
            r => (Id: r.GetLong("platform_id"), Count: (int)r.GetLong("overrides")), ct);

        return rows.ToDictionary(x => x.Id, x => x.Count);
    }

    public async Task<long> InsertAsync(MessageTemplate t, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn,
            @"INSERT INTO message_templates
                (school_id, channel, code, locale, subject, body, provider_template_id,
                 editable_by, is_active)
              VALUES (@sid, @ch, @code, @loc, @subj, @body, @ptid, @edit, @active)",
            ct,
            ("@sid", (object?)t.SchoolId ?? DBNull.Value),
            ("@ch", t.Channel), ("@code", t.Code), ("@loc", t.Locale),
            ("@subj", (object?)t.Subject ?? DBNull.Value),
            ("@body", t.Body),
            ("@ptid", (object?)t.ProviderTemplateId ?? DBNull.Value),
            ("@edit", t.EditableBy), ("@active", t.IsActive));
    }

    public async Task UpdateAsync(MessageTemplate t, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Channel, code and locale are the template's identity — changing them would silently
        // repoint every school override, so they are not updatable here.
        await DbHelper.ExecuteAsync(conn,
            @"UPDATE message_templates
                 SET subject=@subj, body=@body, provider_template_id=@ptid,
                     editable_by=@edit, is_active=@active
               WHERE id=@id",
            ct,
            ("@subj", (object?)t.Subject ?? DBNull.Value),
            ("@body", t.Body),
            ("@ptid", (object?)t.ProviderTemplateId ?? DBNull.Value),
            ("@edit", t.EditableBy), ("@active", t.IsActive), ("@id", t.Id));
    }

    public async Task DeleteAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "DELETE FROM message_templates WHERE id=@id", ct, ("@id", id));
    }
}
