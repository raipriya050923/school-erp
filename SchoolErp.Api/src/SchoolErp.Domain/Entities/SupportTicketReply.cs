namespace SchoolErp.Domain.Entities;

/// <summary>A comment/reply on a support ticket. Maps to `support_ticket_replies`.</summary>
public class SupportTicketReply
{
    public long Id { get; set; }
    public long TicketId { get; set; }
    public long UserId { get; set; }
    public string Message { get; set; } = string.Empty;
    public string? AttachmentUrl { get; set; }
    public DateTime CreatedAt { get; set; }

    // Joined display fields
    public string? AuthorName { get; set; }
    public string? AuthorType { get; set; }  // super_admin | school_admin ... => maps to "platform"/"school" in UI
}
