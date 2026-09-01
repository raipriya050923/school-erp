using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

public class NoticeService : INoticeService
{
    private static readonly string[] ValidAudiences = { "all", "students", "teachers", "staff", "parents", "class" };
    private readonly INoticeRepository _repo;
    private readonly ICurrentSchool _school;
    private readonly ICurrentUser _user;

    public NoticeService(INoticeRepository repo, ICurrentSchool school, ICurrentUser user)
    {
        _repo = repo;
        _school = school;
        _user = user;
    }

    public async Task<IReadOnlyList<NoticeDto>> ListAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetAllAsync(_school.SchoolId, null, ct);
        return rows.Select(ToDto).ToList();
    }

    public async Task<long> CreateAsync(CreateNoticeDto dto, CancellationToken ct = default)
    {
        var (title, body, audience) = Validate(dto);
        var n = new Notice
        {
            SchoolId = _school.SchoolId,
            Title = title,
            Body = body,
            Audience = audience,
            PublishDate = DateTime.UtcNow,
            IsPublished = true,
            // Was hardcoded to the seeded Sunrise admin, which credited every school's notices to
            // one user in another tenant. The token carries the real author.
            CreatedBy = _user.UserId,
        };
        return await _repo.CreateAsync(n, ct);
    }

    public async Task UpdateAsync(long id, CreateNoticeDto dto, CancellationToken ct = default)
    {
        var (title, body, audience) = Validate(dto);
        var notice = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
                     ?? throw new NotFoundException($"Notice {id} not found.");
        notice.Title = title;
        notice.Body = body;
        notice.Audience = audience;
        await _repo.UpdateAsync(notice, ct);
    }

    public async Task DeleteAsync(long id, CancellationToken ct = default)
    {
        _ = await _repo.GetByIdAsync(_school.SchoolId, id, ct)
            ?? throw new NotFoundException($"Notice {id} not found.");
        await _repo.DeleteAsync(_school.SchoolId, id, ct);
    }

    private static (string Title, string Body, string Audience) Validate(CreateNoticeDto dto)
    {
        var title = dto.Title?.Trim() ?? "";
        var body = dto.Body?.Trim() ?? "";
        if (title.Length == 0 || body.Length == 0)
            throw new ValidationException("Title and body are required.");
        var audience = (dto.Audience ?? "").Trim().ToLowerInvariant();
        return (title, body, ValidAudiences.Contains(audience) ? audience : "all");
    }

    private static NoticeDto ToDto(Notice n) =>
        new(n.Id, n.Title, n.Body, n.Audience, n.PublishDate, n.CreatedBy, n.CreatedByName);
}
