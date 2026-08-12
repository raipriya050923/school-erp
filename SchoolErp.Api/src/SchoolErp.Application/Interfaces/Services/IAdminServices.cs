using SchoolErp.Application.DTOs.Admin;

namespace SchoolErp.Application.Interfaces.Services;

public interface IAdminDashboardService
{
    Task<AdminDashboardDto> GetAsync(CancellationToken ct = default);
}

public interface IStudentService
{
    Task<IReadOnlyList<StudentListItemDto>> ListAsync(string? search, string? className, CancellationToken ct = default);
    Task<StudentDetailDto?> GetAsync(long id, CancellationToken ct = default);
    Task<long> CreateAsync(SaveStudentDto dto, CancellationToken ct = default);
    Task UpdateAsync(long id, SaveStudentDto dto, CancellationToken ct = default);
    Task SetStatusAsync(long id, string status, CancellationToken ct = default);
}

public interface ITeacherService
{
    Task<IReadOnlyList<TeacherListItemDto>> ListAsync(string? search, CancellationToken ct = default);
    Task<TeacherDetailDto?> GetAsync(long id, CancellationToken ct = default);
    Task<long> CreateAsync(SaveTeacherDto dto, CancellationToken ct = default);
    Task UpdateAsync(long id, SaveTeacherDto dto, CancellationToken ct = default);
    Task SetStatusAsync(long id, string status, CancellationToken ct = default);
}

public interface IClassService
{
    Task<IReadOnlyList<ClassDto>> ListAsync(CancellationToken ct = default);
    Task<long> CreateClassAsync(CreateClassDto dto, CancellationToken ct = default);
    Task RenameClassAsync(long id, string name, CancellationToken ct = default);
    Task DeleteClassAsync(long id, CancellationToken ct = default);
    Task<long> AddSectionAsync(SaveSectionDto dto, CancellationToken ct = default);
    Task UpdateSectionAsync(long id, SaveSectionDto dto, CancellationToken ct = default);
    Task DeleteSectionAsync(long id, CancellationToken ct = default);
}

public interface INoticeService
{
    Task<IReadOnlyList<NoticeDto>> ListAsync(CancellationToken ct = default);
    Task<long> CreateAsync(CreateNoticeDto dto, CancellationToken ct = default);
}
