namespace SchoolErp.Application.DTOs.Messaging;

/// <summary>
/// A template as the platform console lists it.
/// <paramref name="OverrideCount"/> is how many schools have replaced this default with their
/// own wording — the first thing to check when a school reports that a message reads wrong.
/// </summary>
public record TemplateDto(
    long Id,
    string Channel,
    string Code,
    string Locale,
    string? Subject,
    string Body,
    string? ProviderTemplateId,
    string EditableBy,
    bool IsActive,
    int OverrideCount,
    DateTime UpdatedAt);

/// <summary>
/// A template as a school sees it: the text that will actually go out in their name, plus
/// whether this one is theirs to change.
/// </summary>
public record SchoolTemplateDto(
    string Channel,
    string Code,
    string Locale,
    string? Subject,
    string Body,
    bool IsActive,
    /// <summary>True when the school has supplied its own wording rather than inheriting.</summary>
    bool IsOverridden,
    /// <summary>False when the platform reserves this message — an OTP, for instance.</summary>
    bool CanEdit,
    /// <summary>The platform's wording, so a school can see what it is departing from.</summary>
    string PlatformBody,
    string? PlatformSubject);

public class SaveTemplateDto
{
    public string Channel { get; set; } = "sms";
    public string Code { get; set; } = string.Empty;
    public string Locale { get; set; } = "en";
    public string? Subject { get; set; }
    public string Body { get; set; } = string.Empty;
    public string? ProviderTemplateId { get; set; }

    /// <summary>platform | school — who may reword this message.</summary>
    public string EditableBy { get; set; } = "platform";
    public bool IsActive { get; set; } = true;
}

/// <summary>
/// A school's own wording. Channel, code and locale identify which default is being
/// overridden; they are not a school's to invent, so they are route parameters rather than
/// body fields.
/// </summary>
public class SaveSchoolTemplateDto
{
    public string? Subject { get; set; }
    public string Body { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}

/// <summary>What a template renders to for a given set of values, before anyone sends it.</summary>
public record TemplatePreviewDto(string? Subject, string Body, IReadOnlyList<string> UnfilledPlaceholders);
