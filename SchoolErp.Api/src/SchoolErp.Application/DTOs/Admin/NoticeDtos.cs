namespace SchoolErp.Application.DTOs.Admin;

public record NoticeDto(
    long Id, string Title, string Body, string Audience, DateTime PublishDate,
    // Who published it. The client compares CreatedBy with the signed-in user to offer a
    // "Mine" filter without a second round trip.
    long CreatedBy, string? CreatedByName);

public class CreateNoticeDto
{
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public string Audience { get; set; } = "all";
}
