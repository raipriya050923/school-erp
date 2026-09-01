namespace SchoolErp.Domain.Entities;

/// <summary>An in-app notification addressed to one user. Maps to `notifications`.</summary>
public class Notification
{
    public long Id { get; set; }
    public long? SchoolId { get; set; }
    public long UserId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Body { get; set; }
    /// <summary>Drives the icon shown in the bell menu: admission | fee | ticket | school | general.</summary>
    public string Type { get; set; } = "general";
    public string? RefTable { get; set; }
    public long? RefId { get; set; }
    public DateTime? ReadAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
