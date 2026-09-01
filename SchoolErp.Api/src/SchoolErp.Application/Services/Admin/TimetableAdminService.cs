using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

/// <summary>
/// Builds a section's weekly timetable. A cell's teacher defaults to whoever is assigned to that
/// subject for the section, but can be overridden per period so a stand-in can be booked without
/// disturbing the subject assignment. Clash checks stop one teacher or room being booked twice.
/// </summary>
public class TimetableAdminService : ITimetableAdminService
{
    private readonly ITimetableRepository _repo;
    private readonly ICurriculumRepository _curriculum;
    private readonly IClassRepository _classes;
    private readonly ISchoolRepository _schools;
    private readonly ITeacherRepository _teachers;
    private readonly ICurrentSchool _school;

    public TimetableAdminService(ITimetableRepository repo, ICurriculumRepository curriculum,
        IClassRepository classes, ISchoolRepository schools, ITeacherRepository teachers,
        ICurrentSchool school)
    {
        _repo = repo;
        _curriculum = curriculum;
        _classes = classes;
        _schools = schools;
        _teachers = teachers;
        _school = school;
    }

    public async Task<SectionTimetableDto> GetAsync(string className, string sectionName, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        if (string.IsNullOrWhiteSpace(className) || string.IsNullOrWhiteSpace(sectionName))
            throw new ValidationException("Choose a class and section.");

        var (cls, section) = await ResolveSectionAsync(className, sectionName, ct);

        var periods = await PeriodsAsync(sid, ct);
        var slots = await _repo.GetForSectionAsync(sid, cls.Name, section.Name, ct);

        var cells = slots.Select(s => new TimetableCellDto(
            s.DayOfWeek, s.PeriodNo, s.Subject, s.TeacherStaffId, s.TeacherName, s.Room)).ToList();

        return new SectionTimetableDto(cls.Name, section.Name, periods, cells,
            await SubjectOptionsAsync(cls.Id, section.Id, ct));
    }

    /// <summary>
    /// The same timetable seen from one teacher rather than one section — the view for filling a
    /// teacher's whole week across the classes they teach. Options come from their subject
    /// assignments, plus anything they are already booked for period by period, so a teacher
    /// scheduled directly still gets a usable week.
    /// </summary>
    public async Task<TeacherWeekDto> GetForTeacherAsync(long staffId, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var teacher = await _teachers.GetByIdAsync(sid, staffId, ct)
                      ?? throw new NotFoundException($"Teacher {staffId} not found.");
        var yearId = await _schools.GetCurrentAcademicYearIdAsync(sid, ct)
                     ?? throw new ValidationException(
                         "This school has no academic year set up, so periods cannot be scheduled yet.");

        var periods = await PeriodsAsync(sid, ct);
        var assignments = await _curriculum.GetAssignmentsForTeacherAsync(sid, yearId, staffId, ct);

        var options = assignments.Select(a => new TeacherAssignmentOptionDto(
            a.ClassId, a.ClassName ?? "", a.SectionId, a.SectionName ?? "", a.SubjectName ?? "")).ToList();

        var mine = await _repo.GetByTeacherAsync(sid, staffId, ct);
        var cells = mine.Select(s => new TeacherWeekCellDto(
            s.DayOfWeek, s.PeriodNo, s.ClassLabel, s.SectionLabel, s.Subject, s.Room)).ToList();

        // A teacher can be booked for a single period directly, with no subject assignment behind
        // it. Whatever they are already scheduled to teach is therefore a valid option too —
        // without this the view has nothing to offer and refuses to draw their week at all.
        var classes = await _classes.GetAllWithSectionsAsync(sid, ct);
        foreach (var slot in mine)
        {
            if (string.IsNullOrWhiteSpace(slot.Subject)) continue;
            if (options.Any(o => Same(o.ClassName, slot.ClassLabel)
                                 && Same(o.SectionName, slot.SectionLabel)
                                 && Same(o.Subject, slot.Subject))) continue;

            // A label that no longer matches a live section is skipped rather than fatal — the
            // period still shows in the grid, it just cannot be re-pointed from here.
            var cls = classes.FirstOrDefault(c => Same(c.Name, slot.ClassLabel));
            var section = cls?.Sections.FirstOrDefault(x => Same(x.Name, slot.SectionLabel));
            if (cls is null || section is null) continue;

            options.Add(new TeacherAssignmentOptionDto(cls.Id, cls.Name, section.Id, section.Name, slot.Subject!));
        }

        // What else is already booked in those same sections, so the picker can warn before an
        // assignment overwrites a colleague's period.
        var busy = new List<SectionBusyDto>();
        foreach (var section in options.Select(o => (o.ClassName, o.SectionName)).Distinct())
        {
            var slots = await _repo.GetForSectionAsync(sid, section.ClassName, section.SectionName, ct);
            busy.AddRange(slots.Select(s => new SectionBusyDto(
                s.DayOfWeek, s.PeriodNo, section.ClassName, section.SectionName, s.Subject, s.TeacherName)));
        }

        return new TeacherWeekDto(staffId, $"{teacher.FirstName} {teacher.LastName}".Trim(),
            periods, cells, options, busy, await WorkingDaysAsync(sid, ct));
    }

    /// <summary>
    /// The whole school for one day: a row per section, a column per period. This is the screen
    /// for laying out a day in one pass — a clash shows up as the same teacher twice in a column.
    /// </summary>
    public async Task<DayTimetableDto> GetDayAsync(int dayOfWeek, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        if (dayOfWeek is < 1 or > 7) throw new ValidationException("Pick a day of the week.");

        var periods = await PeriodsAsync(sid, ct);
        var classes = await _classes.GetAllWithSectionsAsync(sid, ct);

        var rows = new List<DayRowDto>();
        foreach (var cls in classes)
        {
            foreach (var section in cls.Sections)
            {
                var slots = await _repo.GetForSectionAsync(sid, cls.Name, section.Name, ct);
                var cells = slots
                    .Where(s => s.DayOfWeek == dayOfWeek)
                    .Select(s => new TimetableCellDto(s.DayOfWeek, s.PeriodNo, s.Subject,
                        s.TeacherStaffId, s.TeacherName, s.Room))
                    .ToList();

                rows.Add(new DayRowDto(cls.Id, cls.Name, section.Id, section.Name, cells,
                    await SubjectOptionsAsync(cls.Id, section.Id, ct)));
            }
        }

        return new DayTimetableDto(dayOfWeek, periods, rows, await WorkingDaysAsync(sid, ct));
    }

    public async Task SaveSlotAsync(SaveTimetableSlotDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        if (dto.DayOfWeek is < 1 or > 7) throw new ValidationException("Pick a day of the week.");
        if (dto.PeriodNo <= 0) throw new ValidationException("Pick a period.");

        var (cls, section) = await ResolveSectionAsync(dto.ClassName, dto.SectionName, ct);

        var working = await WorkingDaysAsync(sid, ct);
        if (!working.Contains(dto.DayOfWeek) && !string.IsNullOrWhiteSpace(dto.Subject))
            throw new ValidationException($"{DayName(dto.DayOfWeek)} is not a working day at this school.");

        // Blank subject means "empty this period".
        if (string.IsNullOrWhiteSpace(dto.Subject))
        {
            await _repo.ClearSlotAsync(sid, cls.Name, section.Name, dto.DayOfWeek, dto.PeriodNo, ct);
            return;
        }

        var subject = dto.Subject.Trim();
        var options = await SubjectOptionsAsync(cls.Id, section.Id, ct);
        var option = options.FirstOrDefault(o => string.Equals(o.Subject, subject, StringComparison.OrdinalIgnoreCase))
                     ?? throw new ValidationException(
                         $"{cls.Name} does not study {subject}. Add it under Subjects & Teachers first.");

        var periods = await PeriodsAsync(sid, ct);
        var period = periods.FirstOrDefault(p => p.PeriodNo == dto.PeriodNo)
                     ?? throw new ValidationException("That period is not on the school's timetable.");
        if (period.IsBreak)
            throw new ValidationException($"{period.Name} is a break and cannot hold a class.");

        var room = string.IsNullOrWhiteSpace(dto.Room) ? null : dto.Room.Trim();

        // The caller decides the teacher for this period; when they send none we
        // fall back to whoever is assigned to the subject for this section.
        var teacherId = dto.TeacherStaffId ?? option.TeacherStaffId;
        var teacherName = option.TeacherName;

        if (dto.TeacherStaffId is { } chosen && chosen != option.TeacherStaffId)
        {
            var staff = await _teachers.GetByIdAsync(sid, chosen, ct)
                        ?? throw new ValidationException("That teacher is not on this school's staff.");

            teacherName = $"{staff.FirstName} {staff.LastName}".Trim();
        }

        if (teacherId is { } staffId)
        {
            var clash = await _repo.FindTeacherClashAsync(sid, staffId, dto.DayOfWeek, dto.PeriodNo,
                cls.Name, section.Name, ct);
            if (clash is not null)
                throw new ValidationException(
                    $"{teacherName} already teaches {clash.ClassLabel}-{clash.SectionLabel} " +
                    $"in {period.Name} on {DayName(dto.DayOfWeek)}.");
        }

        if (room is not null)
        {
            var clash = await _repo.FindRoomClashAsync(sid, room, dto.DayOfWeek, dto.PeriodNo,
                cls.Name, section.Name, ct);
            if (clash is not null)
                throw new ValidationException(
                    $"Room {room} is taken by {clash.ClassLabel}-{clash.SectionLabel} " +
                    $"in {period.Name} on {DayName(dto.DayOfWeek)}.");
        }

        await _repo.UpsertSlotAsync(new TimetableSlot
        {
            SchoolId = sid,
            ClassLabel = cls.Name,
            SectionLabel = section.Name,
            DayOfWeek = dto.DayOfWeek,
            PeriodNo = dto.PeriodNo,
            TimeLabel = period.TimeLabel,
            Subject = option.Subject,
            Room = room,
            TeacherStaffId = teacherId,
        }, ct);
    }

    /// <summary>Periods, seeded on first use so a new school is not left with an empty grid.</summary>
    private async Task<IReadOnlyList<TimetablePeriodDto>> PeriodsAsync(long schoolId, CancellationToken ct)
    {
        var rows = await _repo.GetPeriodsAsync(schoolId, ct);
        if (rows.Count == 0)
        {
            await _repo.SeedDefaultPeriodsAsync(schoolId, ct);
            rows = await _repo.GetPeriodsAsync(schoolId, ct);
        }
        // period_no is the running order, breaks included, so the grid columns line up with it.
        return rows.Select((p, i) => new TimetablePeriodDto(
            i + 1, p.Name, $"{p.StartTime:hh\\:mm}–{p.EndTime:hh\\:mm}", p.IsBreak)).ToList();
    }

    /// <summary>What the class studies, each paired with the teacher assigned to this section.</summary>
    private async Task<IReadOnlyList<TimetableSubjectOptionDto>> SubjectOptionsAsync(long classId, long sectionId,
        CancellationToken ct)
    {
        var sid = _school.SchoolId;
        var yearId = await _schools.GetCurrentAcademicYearIdAsync(sid, ct)
                     ?? throw new ValidationException(
                         "This school has no academic year set up, so subjects cannot be scheduled yet.");

        var subjects = await _curriculum.GetClassSubjectsAsync(sid, yearId, classId, ct);
        var assignments = await _curriculum.GetAssignmentsForClassAsync(sid, yearId, classId, ct);

        return subjects.Select(cs =>
        {
            var hit = assignments.FirstOrDefault(a => a.SectionId == sectionId && a.SubjectId == cs.SubjectId);
            return new TimetableSubjectOptionDto(cs.SubjectName ?? "", hit?.StaffId, hit?.TeacherName);
        }).ToList();
    }

    private static bool Same(string? a, string? b) =>
        string.Equals(a, b, StringComparison.OrdinalIgnoreCase);

    private async Task<(SchoolClass Class, ClassSection Section)> ResolveSectionAsync(string className,
        string sectionName, CancellationToken ct)
    {
        var classes = await _classes.GetAllWithSectionsAsync(_school.SchoolId, ct);
        var cls = classes.FirstOrDefault(c => string.Equals(c.Name, className, StringComparison.OrdinalIgnoreCase))
                  ?? throw new NotFoundException($"Class {className} not found.");
        var section = cls.Sections.FirstOrDefault(s => string.Equals(s.Name, sectionName, StringComparison.OrdinalIgnoreCase))
                      ?? throw new NotFoundException($"Section {sectionName} not found in {cls.Name}.");
        return (cls, section);
    }

    /// <summary>
    /// Fills the day's empty periods with a clash-free suggestion.
    ///
    /// Greedy, one period at a time across all sections: for each empty cell it takes the
    /// section's least-used subject whose teacher is still free in that period. That keeps a
    /// teacher out of two rooms at once by construction, and spreads subjects across the day
    /// rather than stacking one subject in consecutive periods. Anything already scheduled is
    /// left untouched and counts as occupied, so the suggestion works around it.
    ///
    /// It is a starting point, not a solver: where no subject fits, the period is left empty and
    /// reported rather than forced.
    /// </summary>
    public async Task<AutoFillResultDto> AutoFillDayAsync(int dayOfWeek, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var working = await WorkingDaysAsync(sid, ct);
        if (!working.Contains(dayOfWeek))
            throw new ValidationException($"{DayName(dayOfWeek)} is not a working day at this school.");

        var day = await GetDayAsync(dayOfWeek, ct);
        var teaching = day.Periods.Where(p => !p.IsBreak).Select(p => p.PeriodNo).ToList();

        // Teachers already committed in each period, from what is on the grid.
        var busy = teaching.ToDictionary(p => p, _ => new HashSet<long>());
        foreach (var row in day.Rows)
            foreach (var cell in row.Cells.Where(c => c.TeacherStaffId is not null))
                if (busy.TryGetValue(cell.PeriodNo, out var set)) set.Add(cell.TeacherStaffId!.Value);

        // How often each subject already appears in a section today, so repeats come last.
        var used = day.Rows.ToDictionary(
            r => r.SectionId,
            r => r.Cells.Where(c => c.Subject is not null)
                  .GroupBy(c => c.Subject!)
                  .ToDictionary(g => g.Key, g => g.Count()));

        var filled = 0;
        var leftEmpty = 0;
        var notes = new List<string>();

        foreach (var period in teaching)
        {
            foreach (var row in day.Rows)
            {
                if (row.Cells.Any(c => c.PeriodNo == period)) continue;   // already set — leave it
                if (row.Subjects.Count == 0)
                {
                    leftEmpty++;
                    continue;
                }

                var counts = used[row.SectionId];
                var choice = row.Subjects
                    .Where(o => o.TeacherStaffId is null || !busy[period].Contains(o.TeacherStaffId.Value))
                    .OrderBy(o => counts.TryGetValue(o.Subject, out var n) ? n : 0)
                    .ThenBy(o => o.Subject, StringComparer.OrdinalIgnoreCase)
                    .FirstOrDefault();

                if (choice is null)
                {
                    leftEmpty++;
                    notes.Add($"{row.ClassName}-{row.SectionName} period {period}: every teacher was already busy.");
                    continue;
                }

                await _repo.UpsertSlotAsync(new TimetableSlot
                {
                    SchoolId = sid,
                    ClassLabel = row.ClassName,
                    SectionLabel = row.SectionName,
                    DayOfWeek = dayOfWeek,
                    PeriodNo = period,
                    TimeLabel = day.Periods.First(p => p.PeriodNo == period).TimeLabel,
                    Subject = choice.Subject,
                    TeacherStaffId = choice.TeacherStaffId,
                }, ct);

                if (choice.TeacherStaffId is { } staff) busy[period].Add(staff);
                counts[choice.Subject] = (counts.TryGetValue(choice.Subject, out var c) ? c : 0) + 1;
                filled++;
            }
        }

        var noSubjects = day.Rows.Where(r => r.Subjects.Count == 0)
            .Select(r => $"{r.ClassName}-{r.SectionName}").ToList();
        if (noSubjects.Count > 0)
            notes.Insert(0, $"No subjects set for {string.Join(", ", noSubjects)} — add them under Subjects & Teachers.");

        return new AutoFillResultDto(filled, leftEmpty, notes.Take(6).ToList());
    }

    /// <summary>The school's working days, parsed from its stored list and always in order.</summary>
    private async Task<IReadOnlyList<int>> WorkingDaysAsync(long schoolId, CancellationToken ct)
    {
        var school = await _schools.GetByIdAsync(schoolId, ct);
        var days = (school?.WorkingDays ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(d => int.TryParse(d, out var n) ? n : 0)
            .Where(n => n is >= 1 and <= 7)
            .Distinct().OrderBy(n => n).ToList();
        // A school with nothing configured still needs a week to work with.
        return days.Count > 0 ? days : new List<int> { 1, 2, 3, 4, 5, 6 };
    }

    public async Task SetWorkingDaysAsync(SaveWorkingDaysDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var days = (dto.Days ?? Array.Empty<int>())
            .Where(d => d is >= 1 and <= 7).Distinct().OrderBy(d => d).ToList();
        if (days.Count == 0) throw new ValidationException("Pick at least one working day.");

        // Dropping a day that already holds periods would strand them out of sight rather than
        // deleting them, so say what is in the way instead.
        var dropped = Enumerable.Range(1, 7).Except(days).ToList();
        foreach (var day in dropped)
        {
            var used = await _repo.CountSlotsOnDayAsync(sid, day, ct);
            if (used > 0)
                throw new ValidationException(
                    $"{DayName(day)} still has {used} scheduled period(s). Clear them before marking it a holiday.");
        }

        await _schools.SetWorkingDaysAsync(sid, string.Join(',', days), ct);
    }

    private static string DayName(int day) => day switch
    {
        1 => "Sunday", 2 => "Monday", 3 => "Tuesday", 4 => "Wednesday",
        5 => "Thursday", 6 => "Friday", _ => "Saturday",
    };
}
