namespace SchoolErp.Domain.Entities;

/// <summary>A notice-board entry. Maps to `notices`.</summary>
public class Notice
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public string Audience { get; set; } = "all";  // all | students | teachers | staff | parents | class
    public DateTime PublishDate { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public bool IsPublished { get; set; } = true;
    public long CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
