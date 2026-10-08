using SchoolErp.Application.DTOs.Admin;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>Class subject lists and the subject-teacher grid behind them.</summary>
public interface ICurriculumService
{
    Task<ClassCurriculumDto> GetAsync(long classId, CancellationToken ct = default);
    /// <summary>
    /// Every class with the subjects it studies this year. One call for screens that need to
    /// know what a class may be examined in, rather than one request per class.
    /// </summary>
    Task<IReadOnlyList<ClassSubjectsDto>> SubjectsByClassAsync(CancellationToken ct = default);
    Task SetSubjectsAsync(long classId, SetClassSubjectsDto dto, CancellationToken ct = default);
    Task AssignAsync(SaveAssignmentDto dto, CancellationToken ct = default);
    /// <summary>Unassigns every subject teacher for a class. Returns how many were cleared.</summary>
    Task<int> ClearAssignmentsAsync(long classId, CancellationToken ct = default);
}
