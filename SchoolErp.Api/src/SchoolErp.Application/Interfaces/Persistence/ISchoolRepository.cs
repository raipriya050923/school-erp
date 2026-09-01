using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface ISchoolRepository
{
    Task<IReadOnlyList<School>> GetAllAsync(string? search, string? status, CancellationToken ct = default);
    Task<School?> GetByIdAsync(long id, CancellationToken ct = default);
    Task<long> CreateAsync(School school, CancellationToken ct = default);
    Task UpdateAsync(School school, CancellationToken ct = default);
    Task UpdateStatusAsync(long id, string status, CancellationToken ct = default);
    Task<bool> ExistsByNameAsync(string name, long? excludeId, CancellationToken ct = default);
    Task<int> CountAsync(CancellationToken ct = default);
    Task<int> GetStudentCountAsync(long schoolId, CancellationToken ct = default);
    /// <summary>Name of the school's current academic year, or null if none is flagged current.</summary>
    Task<string?> GetCurrentAcademicYearAsync(long schoolId, CancellationToken ct = default);
    /// <summary>All academic years for a school, newest first, with the current one flagged.</summary>
    Task<IReadOnlyList<(long Id, string Name, bool IsCurrent)>> GetAcademicYearsAsync(long schoolId, CancellationToken ct = default);
    /// <summary>Id of the year flagged current, or the latest one; null when the school has none.</summary>
    Task<long?> GetCurrentAcademicYearIdAsync(long schoolId, CancellationToken ct = default);
    /// <summary>
    /// Gives a new school previous/current/next academic years on an April–March calendar.
    /// A school without one cannot schedule subjects, exams or assignments, all of which are
    /// keyed by academic year. No-op when the school already has years.
    /// </summary>
    Task SeedDefaultAcademicYearsAsync(long schoolId, CancellationToken ct = default);
    /// <summary>Days the school runs, as a comma-separated day-of-week list.</summary>
    Task SetWorkingDaysAsync(long schoolId, string days, CancellationToken ct = default);
}
