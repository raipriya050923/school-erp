using SchoolErp.Application.DTOs.Transactional;

namespace SchoolErp.Application.DTOs.Admin;

/// <summary>One cell: what is taught, by whom, where.</summary>
public record TimetableCellDto(int DayOfWeek, int PeriodNo, string? Subject, long? TeacherStaffId,
    string? TeacherName, string? Room);

/// <summary>
/// A section's week. Subjects are the ones the class studies, so a period can only be filled
/// with something the class actually takes.
/// </summary>
public record SectionTimetableDto(
    string ClassName,
    string SectionName,
    IReadOnlyList<TimetablePeriodDto> Periods,
    IReadOnlyList<TimetableCellDto> Cells,
    IReadOnlyList<TimetableSubjectOptionDto> Subjects);

/// <summary>A subject the class studies, with the teacher assigned to teach it to this section.</summary>
public record TimetableSubjectOptionDto(string Subject, long? TeacherStaffId, string? TeacherName);

public class SaveTimetableSlotDto
{
    public string ClassName { get; set; } = string.Empty;
    public string SectionName { get; set; } = string.Empty;
    /// <summary>1 = Sunday … 6 = Friday, matching the stored values.</summary>
    public int DayOfWeek { get; set; }
    public int PeriodNo { get; set; }
    /// <summary>Null or blank clears the cell.</summary>
    public string? Subject { get; set; }
    public string? Room { get; set; }

    /// <summary>
    /// Who teaches this one period. Overrides the subject's assigned teacher,
    /// so a stand-in can be booked without changing the subject assignment.
    /// Null means the period has no teacher.
    /// </summary>
    public long? TeacherStaffId { get; set; }
}

/* ---- teacher-centric view: fill one teacher's week across several classes ---- */

/// <summary>A period this teacher already teaches.</summary>
public record TeacherWeekCellDto(int DayOfWeek, int PeriodNo, string? ClassName, string? SectionName,
    string? Subject, string? Room);

/// <summary>A class/section/subject this teacher is assigned to, i.e. what they may be scheduled for.</summary>
public record TeacherAssignmentOptionDto(long ClassId, string ClassName, long SectionId, string SectionName,
    string Subject);

/// <summary>
/// A period already taken in one of the teacher's sections — by them or by a colleague. Lets the
/// picker say "Grade 1-A is already doing Mathematics then" before the admin overwrites it.
/// </summary>
public record SectionBusyDto(int DayOfWeek, int PeriodNo, string ClassName, string SectionName,
    string? Subject, string? TeacherName);

public record TeacherWeekDto(
    long StaffId,
    string TeacherName,
    IReadOnlyList<TimetablePeriodDto> Periods,
    IReadOnlyList<TeacherWeekCellDto> Cells,
    IReadOnlyList<TeacherAssignmentOptionDto> Options,
    IReadOnlyList<SectionBusyDto> SectionBusy,
    IReadOnlyList<int> WorkingDays);

/* ---- whole-school day grid: every section's periods for one day, on one screen ---- */

/// <summary>One section's row in the day grid: its periods, and what it may be scheduled for.</summary>
public record DayRowDto(
    long ClassId, string ClassName, long SectionId, string SectionName,
    IReadOnlyList<TimetableCellDto> Cells,
    IReadOnlyList<TimetableSubjectOptionDto> Subjects);

public record DayTimetableDto(
    int DayOfWeek,
    IReadOnlyList<TimetablePeriodDto> Periods,
    IReadOnlyList<DayRowDto> Rows,
    /// <summary>Days this school runs; days outside it are not offered.</summary>
    IReadOnlyList<int> WorkingDays);

/* ---- period columns: the shape of the school day ---- */

/// <summary>
/// A period as the admin manages it. <paramref name="PeriodNo"/> is its running position in the
/// day, breaks included — the same number the grid cells are keyed on. <paramref name="ScheduledCount"/>
/// is how many cells school-wide sit in it, so the screen can say what a delete would strand.
/// </summary>
public record PeriodDto(long Id, int PeriodNo, string Name, string StartTime, string EndTime,
    int DurationMinutes, bool IsBreak, int ScheduledCount);

/// <summary>
/// A period is entered as a start time plus how long it runs — that is how a school day is
/// actually decided — and the end time is derived, so two fields can never disagree.
/// </summary>
public class SavePeriodDto
{
    public string Name { get; set; } = string.Empty;
    /// <summary>"HH:mm" on a 24-hour clock.</summary>
    public string StartTime { get; set; } = string.Empty;
    public int DurationMinutes { get; set; }
    /// <summary>A break holds no class; the grid greys it out and refuses subjects in it.</summary>
    public bool IsBreak { get; set; }
}

public class SaveWorkingDaysDto
{
    /// <summary>Day-of-week numbers the school runs: 1 = Sunday … 7 = Saturday.</summary>
    public IReadOnlyList<int> Days { get; set; } = Array.Empty<int>();
}

/// <summary>
/// What to wipe. A day on its own is the common case — one day was filled badly and is being
/// redone — so clearing the whole week has to be asked for explicitly rather than being the
/// default an empty body falls into.
/// </summary>
public class ResetTimetableDto
{
    /// <summary>1 = Sunday … 7 = Saturday. Null clears every day.</summary>
    public int? DayOfWeek { get; set; }
}

/// <summary>How many cells a reset removed, so the admin can see it did what they meant.</summary>
public record ResetTimetableResultDto(int Cleared, string Scope);

/// <summary>What an auto-fill run did, so the admin can see it worked before reviewing the grid.</summary>
public record AutoFillResultDto(int Filled, int LeftEmpty, IReadOnlyList<string> Notes);
