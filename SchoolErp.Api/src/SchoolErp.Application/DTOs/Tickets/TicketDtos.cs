namespace SchoolErp.Application.DTOs.Tickets;

public record TicketReplyDto(
    long Id,
    long UserId,
    string AuthorName,
    string Side,          // "platform" | "school"
    string Message,
    DateTime CreatedAt);

public record TicketListItemDto(
    long Id,
    string TicketNo,
    long SchoolId,
    string SchoolName,
    string RaisedByName,
    string Subject,
    string Priority,
    string Status,
    int CommentCount,
    DateTime CreatedAt);

public record TicketDetailDto(
    long Id,
    string TicketNo,
    string SchoolName,
    string RaisedByName,
    string Subject,
    string Description,
    string Priority,
    string Status,
    DateTime CreatedAt,
    IReadOnlyList<TicketReplyDto> Comments);

public record UpdateTicketStatusDto(string Status);

public class ResolveTicketDto
{
    public string ResolutionNote { get; set; } = string.Empty;
    public bool NotifySchool { get; set; } = true;
}

public class AddCommentDto
{
    public long UserId { get; set; }       // acting super-admin user id
    public string Message { get; set; } = string.Empty;
}
