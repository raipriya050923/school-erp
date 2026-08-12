namespace SchoolErp.Application.DTOs.Admin;

public record NoticeDto(long Id, string Title, string Body, string Audience, DateTime PublishDate);

public class CreateNoticeDto
{
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public string Audience { get; set; } = "all";
}
