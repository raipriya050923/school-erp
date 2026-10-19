namespace SchoolErp.Domain.Entities;

/// <summary>
/// One outbound message, as text rather than as code. Maps to `message_templates`.
///
/// A row with <see cref="SchoolId"/> null is the platform's default, which every school
/// inherits. A row with a school id is that school's override of the default carrying the
/// same channel, code and locale.
/// </summary>
public class MessageTemplate
{
    public long Id { get; set; }

    /// <summary>Null on the platform default; set on a school's override of it.</summary>
    public long? SchoolId { get; set; }

    /// <summary>sms | email</summary>
    public string Channel { get; set; } = string.Empty;

    /// <summary>What the message is for — `otp_login`, `welcome`, `fee_reminder`.</summary>
    public string Code { get; set; } = string.Empty;

    public string Locale { get; set; } = "en";

    /// <summary>Email only; null for SMS, which has no subject line.</summary>
    public string? Subject { get; set; }

    /// <summary>Placeholders are {{name}}.</summary>
    public string Body { get; set; } = string.Empty;

    /// <summary>
    /// The id this template is registered under with the SMS provider. India's DLT rules
    /// require the sent text to match the registered text exactly, which is the reason
    /// <see cref="EditableBy"/> exists at all.
    /// </summary>
    public string? ProviderTemplateId { get; set; }

    /// <summary>
    /// platform | school. Meaningful only on the platform row: it is the platform deciding,
    /// per message, whether a school may reword it.
    /// </summary>
    public string EditableBy { get; set; } = "platform";

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    /// <summary>True when a school may supply its own wording for this message.</summary>
    public bool SchoolMayEdit => string.Equals(EditableBy, "school", StringComparison.OrdinalIgnoreCase);
}

/// <summary>A message that was actually sent. Maps to `message_log`.</summary>
public class MessageLogEntry
{
    public long Id { get; set; }
    public long? SchoolId { get; set; }
    public string Channel { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string Recipient { get; set; } = string.Empty;
    public string? Subject { get; set; }

    /// <summary>The rendered text, not the template: the template may be edited afterwards.</summary>
    public string Body { get; set; } = string.Empty;

    /// <summary>queued | sent | failed</summary>
    public string Status { get; set; } = "queued";
    public string? ProviderMessageId { get; set; }
    public string? Error { get; set; }

    /// <summary>Smallest currency unit, so costs stay integers.</summary>
    public int? CostMinor { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime? SentAt { get; set; }
}
