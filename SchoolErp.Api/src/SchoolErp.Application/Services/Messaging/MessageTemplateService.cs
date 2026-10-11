using System.Text.RegularExpressions;
using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Messaging;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Messaging;

/// <summary>
/// The template library, and the one rule that governs it: the platform writes every message,
/// and a school may reword one only where the platform said it could.
///
/// That rule is enforced here rather than in the UI. A school console that hides the edit
/// button is a courtesy; a service that refuses the write is the actual control.
/// </summary>
public class MessageTemplateService : IMessageTemplateService
{
    private static readonly string[] Channels = { "sms", "email" };
    private static readonly string[] EditableByValues = { "platform", "school" };

    /// <summary>A GSM-7 SMS is 160 characters; past that the carrier bills a second message.</summary>
    private const int SmsSingleSegment = 160;

    private readonly IMessageTemplateRepository _repo;
    private readonly ICurrentSchool _school;

    public MessageTemplateService(IMessageTemplateRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    /* ---------------------------------------------------------------- platform */

    public async Task<IReadOnlyList<TemplateDto>> ListPlatformAsync(
        string? channel, CancellationToken ct = default)
    {
        var rows = await _repo.GetPlatformAsync(Normalise(channel), ct);
        var counts = await _repo.GetOverrideCountsAsync(ct);
        return rows.Select(t => ToDto(t, counts.TryGetValue(t.Id, out var n) ? n : 0)).ToList();
    }

    public async Task<long> CreateAsync(SaveTemplateDto dto, CancellationToken ct = default)
    {
        Validate(dto);

        var existing = await _repo.GetPlatformOneAsync(
            dto.Channel, dto.Code.Trim(), dto.Locale.Trim(), ct);
        if (existing is not null)
            throw new ValidationException(
                $"A {dto.Channel} template for '{dto.Code}' in '{dto.Locale}' already exists. Edit that one instead.");

        return await _repo.InsertAsync(new MessageTemplate
        {
            SchoolId = null,
            Channel = dto.Channel,
            Code = dto.Code.Trim(),
            Locale = dto.Locale.Trim(),
            Subject = Blank(dto.Subject),
            Body = dto.Body.Trim(),
            ProviderTemplateId = Blank(dto.ProviderTemplateId),
            EditableBy = dto.EditableBy,
            IsActive = dto.IsActive,
        }, ct);
    }

    public async Task UpdatePlatformAsync(long id, SaveTemplateDto dto, CancellationToken ct = default)
    {
        var t = await _repo.GetByIdAsync(id, ct)
            ?? throw new NotFoundException($"Template {id} not found.");
        if (t.SchoolId is not null)
            throw new ValidationException("That is a school's override, not a platform template.");

        Validate(dto, channel: t.Channel);

        t.Subject = Blank(dto.Subject);
        t.Body = dto.Body.Trim();
        t.ProviderTemplateId = Blank(dto.ProviderTemplateId);
        t.EditableBy = dto.EditableBy;
        t.IsActive = dto.IsActive;
        await _repo.UpdateAsync(t, ct);
    }

    public async Task DeletePlatformAsync(long id, CancellationToken ct = default)
    {
        var t = await _repo.GetByIdAsync(id, ct)
            ?? throw new NotFoundException($"Template {id} not found.");
        if (t.SchoolId is not null)
            throw new ValidationException("That is a school's override, not a platform template.");

        // Deleting a default would leave every school that overrode it with a row overriding
        // nothing, and every school that inherited it with no message at all. Switching it off
        // stops it being sent and keeps both of those coherent.
        var counts = await _repo.GetOverrideCountsAsync(ct);
        if (counts.TryGetValue(id, out var n) && n > 0)
            throw new ValidationException(
                $"{n} school(s) have their own version of this message. Switch it off instead of deleting it.");

        await _repo.DeleteAsync(id, ct);
    }

    /* ------------------------------------------------------------------ school */

    public async Task<IReadOnlyList<SchoolTemplateDto>> ListForSchoolAsync(CancellationToken ct = default)
    {
        var schoolId = _school.SchoolId;
        var defaults = await _repo.GetPlatformAsync(null, ct);
        var mine = await _repo.GetSchoolAsync(schoolId, ct);

        // Keyed on what makes two rows the same message, which is also what the unique index
        // keys on.
        var byIdentity = mine.ToDictionary(
            m => (m.Channel, m.Code, m.Locale),
            m => m);

        return defaults.Select(d =>
        {
            byIdentity.TryGetValue((d.Channel, d.Code, d.Locale), out var ov);
            return new SchoolTemplateDto(
                d.Channel, d.Code, d.Locale,
                ov?.Subject ?? d.Subject,
                ov?.Body ?? d.Body,
                // An override may switch a message off for this school alone; with no override
                // the platform's own switch decides.
                ov?.IsActive ?? d.IsActive,
                IsOverridden: ov is not null,
                CanEdit: d.SchoolMayEdit,
                PlatformBody: d.Body,
                PlatformSubject: d.Subject);
        }).ToList();
    }

    public async Task SaveSchoolOverrideAsync(
        string channel, string code, string locale, SaveSchoolTemplateDto dto,
        CancellationToken ct = default)
    {
        var schoolId = _school.SchoolId;
        channel = Normalise(channel);
        code = code.Trim();
        locale = string.IsNullOrWhiteSpace(locale) ? "en" : locale.Trim();

        var def = await _repo.GetPlatformOneAsync(channel, code, locale, ct)
            ?? throw new NotFoundException(
                $"There is no {channel} template called '{code}' to override.");

        // The rule. A school cannot reword a message the platform reserved — an OTP body is
        // registered with the telecom regulator and carries a login code.
        if (!def.SchoolMayEdit)
            throw new ValidationException(
                "This message is set by the platform and cannot be reworded. " +
                "You can still switch it off for your school.");

        if (string.IsNullOrWhiteSpace(dto.Body))
            throw new ValidationException("The message cannot be empty.");

        WarnIfTooLongForOneSms(channel, dto.Body);

        var existing = await _repo.GetSchoolOneAsync(schoolId, channel, code, locale, ct);
        if (existing is null)
        {
            await _repo.InsertAsync(new MessageTemplate
            {
                SchoolId = schoolId,
                Channel = channel,
                Code = code,
                Locale = locale,
                Subject = Blank(dto.Subject),
                Body = dto.Body.Trim(),
                // Carried from the default so the row is self-describing; the platform row is
                // still the only one consulted when deciding whether editing is allowed.
                EditableBy = def.EditableBy,
                ProviderTemplateId = def.ProviderTemplateId,
                IsActive = dto.IsActive,
            }, ct);
        }
        else
        {
            existing.Subject = Blank(dto.Subject);
            existing.Body = dto.Body.Trim();
            existing.IsActive = dto.IsActive;
            await _repo.UpdateAsync(existing, ct);
        }
    }

    /// <summary>Drops a school back to the platform's wording.</summary>
    public async Task ClearSchoolOverrideAsync(
        string channel, string code, string locale, CancellationToken ct = default)
    {
        var existing = await _repo.GetSchoolOneAsync(
            _school.SchoolId, Normalise(channel), code.Trim(),
            string.IsNullOrWhiteSpace(locale) ? "en" : locale.Trim(), ct);

        // Already inheriting is the state being asked for, so this is not an error.
        if (existing is null) return;
        await _repo.DeleteAsync(existing.Id, ct);
    }

    /* --------------------------------------------------------------- rendering */

    /// <summary>
    /// The text a school would actually send, for a given set of values. Reports the
    /// placeholders nothing was supplied for rather than quietly leaving {{braces}} in a
    /// message a parent will read.
    /// </summary>
    public TemplatePreviewDto Preview(string? subject, string body, IDictionary<string, string?> values)
    {
        var rendered = TemplateRenderer.Render(body, values);
        var renderedSubject = subject is null ? null : TemplateRenderer.Render(subject, values);
        var unfilled = TemplateRenderer.Placeholders(body)
            .Concat(subject is null ? Array.Empty<string>() : TemplateRenderer.Placeholders(subject))
            .Where(p => !values.ContainsKey(p) || string.IsNullOrEmpty(values[p]))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        return new TemplatePreviewDto(renderedSubject, rendered, unfilled);
    }

    /* ----------------------------------------------------------------- helpers */

    private static string Normalise(string? channel) =>
        string.IsNullOrWhiteSpace(channel) ? string.Empty : channel.Trim().ToLowerInvariant();

    private static string? Blank(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();

    private void Validate(SaveTemplateDto dto, string? channel = null)
    {
        var ch = Normalise(channel ?? dto.Channel);
        if (!Channels.Contains(ch))
            throw new ValidationException($"Channel must be one of: {string.Join(", ", Channels)}.");
        dto.Channel = ch;

        if (string.IsNullOrWhiteSpace(dto.Code))
            throw new ValidationException("A template code is required.");
        if (!Regex.IsMatch(dto.Code.Trim(), "^[a-z0-9_]+$"))
            throw new ValidationException(
                "The code identifies the message in code, so it is lower case, digits and underscores only.");

        if (string.IsNullOrWhiteSpace(dto.Body))
            throw new ValidationException("The message body is required.");

        if (!EditableByValues.Contains(dto.EditableBy))
            throw new ValidationException(
                $"editableBy must be one of: {string.Join(", ", EditableByValues)}.");

        if (string.IsNullOrWhiteSpace(dto.Locale)) dto.Locale = "en";

        // An email with no subject arrives as "(no subject)" and reads as spam.
        if (ch == "email" && string.IsNullOrWhiteSpace(dto.Subject))
            throw new ValidationException("An email template needs a subject.");

        WarnIfTooLongForOneSms(ch, dto.Body);
    }

    /// <summary>
    /// Refuses an SMS body that cannot fit one segment once its placeholders are filled.
    ///
    /// The check is on the template with its braces removed, which understates the final
    /// length — a {{name}} is 8 characters here and may be 20 when sent. It is a floor, not a
    /// guarantee, and it is here because the alternative is a school discovering the overflow
    /// on its phone bill.
    /// </summary>
    private static void WarnIfTooLongForOneSms(string channel, string body)
    {
        if (channel != "sms") return;
        var bare = Regex.Replace(body, @"\{\{\s*[\w.]+\s*\}\}", string.Empty).Trim();
        if (bare.Length > SmsSingleSegment)
            throw new ValidationException(
                $"This SMS is {bare.Length} characters before any placeholder is filled in, " +
                $"and one message is {SmsSingleSegment}. Shorten it, or it will be billed as two.");
    }

    private static TemplateDto ToDto(MessageTemplate t, int overrides) => new(
        t.Id, t.Channel, t.Code, t.Locale, t.Subject, t.Body,
        t.ProviderTemplateId, t.EditableBy, t.IsActive, overrides, t.UpdatedAt);
}

/// <summary>
/// Fills {{placeholders}}. Deliberately not a templating engine: the bodies are one or two
/// sentences written by an administrator, and anything that could evaluate an expression in
/// them would be a way to run code from a database row.
/// </summary>
public static class TemplateRenderer
{
    private static readonly Regex Token = new(@"\{\{\s*([\w.]+)\s*\}\}", RegexOptions.Compiled);

    public static string Render(string template, IDictionary<string, string?> values)
    {
        if (string.IsNullOrEmpty(template)) return string.Empty;
        return Token.Replace(template, m =>
        {
            var key = m.Groups[1].Value;
            // An unknown placeholder is left as it stands rather than blanked: a message
            // reading "due on {{due_date}}" is obviously broken, where "due on " looks fine
            // and is worse.
            return values.TryGetValue(key, out var v) && v is not null ? v : m.Value;
        });
    }

    /// <summary>Every placeholder a template uses, in the order they appear.</summary>
    public static IReadOnlyList<string> Placeholders(string template) =>
        string.IsNullOrEmpty(template)
            ? Array.Empty<string>()
            : Token.Matches(template).Select(m => m.Groups[1].Value).Distinct().ToList();
}
