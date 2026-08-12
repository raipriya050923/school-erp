namespace SchoolErp.Domain.Entities;

/// <summary>A support ticket raised by a school. Maps to `support_tickets`.</summary>
public class SupportTicket
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long RaisedBy { get; set; }
    public long? AssignedTo { get; set; }
    public string TicketNo { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Priority { get; set; } = "medium";  // low | medium | high | urgent
    public string Status { get; set; } = "open";       // open | in_progress | waiting | resolved | closed
    public DateTime? ClosedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Joined display fields
    public string? SchoolName { get; set; }
    public string? RaisedByName { get; set; }
    public List<SupportTicketReply> Replies { get; set; } = new();
}
