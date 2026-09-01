using SchoolErp.Application.DTOs.Admin;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>Builds a section's weekly timetable, with clash checks across the whole school.</summary>
public interface ITimetableAdminService
{
    Task<SectionTimetableDto> GetAsync(string className, string sectionName, CancellationToken ct = default);
    /// <summary>One teacher's week, with the class/section/subject slots they may be scheduled into.</summary>
    Task<TeacherWeekDto> GetForTeacherAsync(long staffId, CancellationToken ct = default);
    /// <summary>Every section's row for one day — the whole school on a single grid.</summary>
    Task<DayTimetableDto> GetDayAsync(int dayOfWeek, CancellationToken ct = default);
    /// <summary>Sets which days the school runs; a day with periods already on it cannot be dropped.</summary>
    Task SetWorkingDaysAsync(SaveWorkingDaysDto dto, CancellationToken ct = default);
    /// <summary>
    /// Suggests subjects for the day's empty periods without double-booking any teacher.
    /// Periods already set are left alone, and every suggestion can be changed afterwards.
    /// </summary>
    Task<AutoFillResultDto> AutoFillDayAsync(int dayOfWeek, CancellationToken ct = default);
    /// <summary>Sets one cell; a blank subject clears it.</summary>
    Task SaveSlotAsync(SaveTimetableSlotDto dto, CancellationToken ct = default);
}
