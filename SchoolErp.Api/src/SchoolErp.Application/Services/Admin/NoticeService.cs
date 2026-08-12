using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

public class NoticeService : INoticeService
{
    private readonly INoticeRepository _repo;
    private readonly ICurrentSchool _school;

    public NoticeService(INoticeRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    public async Task<IReadOnlyList<NoticeDto>> ListAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetAllAsync(_school.SchoolId, null, ct);
        return rows.Select(n => new NoticeDto(n.Id, n.Title, n.Body, n.Audience, n.PublishDate)).ToList();
    }

    public async Task<long> CreateAsync(CreateNoticeDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Title) || string.IsNullOrWhiteSpace(dto.Body))
            throw new ValidationException("Title and body are required.");
        var n = new Notice
        {
            SchoolId = _school.SchoolId,
            Title = dto.Title.Trim(),
            Body = dto.Body.Trim(),
            Audience = string.IsNullOrWhiteSpace(dto.Audience) ? "all" : dto.Audience.ToLowerInvariant(),
            PublishDate = DateTime.UtcNow,
            IsPublished = true,
            CreatedBy = 11,   // Sunrise school admin (Anita) from the seed; wire to auth later
        };
        return await _repo.CreateAsync(n, ct);
    }
}
