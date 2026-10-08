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

    /// <summary>
    /// Empties the grid so it can be built again. Only the scheduled cells go: the period
    /// columns and the school's working days are how the week is shaped, not what is in it, and
    /// wiping those would leave the admin with nothing to rebuild onto.
    /// </summary>
    public async Task<ResetTimetableResultDto> ResetAsync(ResetTimetableDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var day = dto?.DayOfWeek;
        if (day is not null && day is < 1 or > 7)
            throw new ValidationException("That is not a day of the week.");

        var cleared = await _repo.ClearSlotsAsync(sid, day, ct);
        return new ResetTimetableResultDto(cleared, day is null ? "the whole week" : DayName(day.Value));
    }

    // ================================================================= periods
    //
    // A cell is keyed on the period's *position* in the day (period_no), not on the period row's
    // id, so every structural change here has to renumber the cells that sit after it — otherwise
    // adding a morning period silently slides every subject one column to the right. Position is
    // derived from the clock rather than kept by hand: periods cannot overlap, so their start
    // times already order the day, and there is no separate "reorder" step to get out of step.

    /// <summary>Shortest and longest a period may run — a typo of 5 hours is not a school day.</summary>
    private const int MinDurationMinutes = 5;
    private const int MaxDurationMinutes = 480;

    public async Task<IReadOnlyList<PeriodDto>> GetPeriodsAsync(CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var rows = await SeededPeriodsAsync(sid, ct);

        var list = new List<PeriodDto>(rows.Count);
        for (var i = 0; i < rows.Count; i++)
        {
            var p = rows[i];
            list.Add(new PeriodDto(
                p.Id, i + 1, p.Name,
                Clock(p.StartTime), Clock(p.EndTime),
                (int)(p.EndTime - p.StartTime).TotalMinutes,
                p.IsBreak,
                await _repo.CountSlotsAtPeriodAsync(sid, i + 1, ct)));
        }
        return list;
    }

    public async Task<long> CreatePeriodAsync(SavePeriodDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var (name, start, end) = ValidatePeriod(dto);

        var rows = await SeededPeriodsAsync(sid, ct);
        EnsureNoClash(rows, name, start, end, excludeId: null);

        // The day is ordered by the clock, so the new period lands after everything starting
        // earlier — and the cells from that position on have to make room for it.
        var position = rows.Count(p => p.StartTime < start) + 1;
        await _repo.OpenSlotGapAsync(sid, position, ct);

        var id = await _repo.InsertPeriodAsync(new TimetablePeriod
        {
            SchoolId = sid,
            Name = name,
            StartTime = start,
            EndTime = end,
            IsBreak = dto.IsBreak,
            SortOrder = position,
        }, ct);

        await ResequenceAsync(sid, ct);
        return id;
    }

    public async Task UpdatePeriodAsync(long id, SavePeriodDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var (name, start, end) = ValidatePeriod(dto);

        var rows = await SeededPeriodsAsync(sid, ct);
        var index = rows.FindIndex(p => p.Id == id);
        if (index < 0) throw new NotFoundException("That period is not on this school's timetable.");

        var existing = rows[index];
        EnsureNoClash(rows, name, start, end, excludeId: id);

        var from = index + 1;
        var scheduled = await _repo.CountSlotsAtPeriodAsync(sid, from, ct);

        // Turning a teaching period into a break would hide whatever is in it rather than
        // delete it, so say what is in the way instead.
        if (dto.IsBreak && !existing.IsBreak && scheduled > 0)
            throw new ValidationException(
                $"{existing.Name} still has {scheduled} scheduled period(s) across the school. " +
                "Clear them before making it a break.");

        // Retiming a period can move it past its neighbours; its cells travel with it.
        var to = rows.Where(p => p.Id != id).Count(p => p.StartTime < start) + 1;
        await _repo.MoveSlotPeriodAsync(sid, from, to, ct);

        await _repo.UpdatePeriodAsync(new TimetablePeriod
        {
            Id = id,
            SchoolId = sid,
            Name = name,
            StartTime = start,
            EndTime = end,
            IsBreak = dto.IsBreak,
        }, ct);

        await ResequenceAsync(sid, ct);
    }

    public async Task DeletePeriodAsync(long id, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var rows = await SeededPeriodsAsync(sid, ct);
        var index = rows.FindIndex(p => p.Id == id);
        if (index < 0) throw new NotFoundException("That period is not on this school's timetable.");

        var position = index + 1;
        var scheduled = await _repo.CountSlotsAtPeriodAsync(sid, position, ct);
        if (scheduled > 0)
            throw new ValidationException(
                $"{rows[index].Name} still has {scheduled} scheduled period(s) across the school. " +
                "Clear them before deleting it.");

        await _repo.DeletePeriodAsync(sid, id, ct);
        await _repo.CloseSlotGapAsync(sid, position, ct);
        await ResequenceAsync(sid, ct);
    }

    /// <summary>
    /// Reads the entered start time and duration back as a clean name and a start/end pair.
    /// The end time is always derived, so the two can never drift apart.
    /// </summary>
    private static (string Name, TimeSpan Start, TimeSpan End) ValidatePeriod(SavePeriodDto dto)
    {
        var name = (dto.Name ?? string.Empty).Trim();
        if (name.Length == 0) throw new ValidationException("Give the period a name, e.g. P1 or Lunch.");
        if (name.Length > 40) throw new ValidationException("Period name is too long (40 characters max).");

        if (!TimeSpan.TryParse((dto.StartTime ?? string.Empty).Trim(), out var start)
            || start < TimeSpan.Zero || start >= TimeSpan.FromDays(1))
            throw new ValidationException("Enter a start time as HH:mm, e.g. 10:00.");
        start = new TimeSpan(start.Hours, start.Minutes, 0);

        if (dto.DurationMinutes < MinDurationMinutes || dto.DurationMinutes > MaxDurationMinutes)
            throw new ValidationException(
                $"Duration must be between {MinDurationMinutes} and {MaxDurationMinutes} minutes.");

        var end = start + TimeSpan.FromMinutes(dto.DurationMinutes);
        if (end >= TimeSpan.FromDays(1))
            throw new ValidationException("A period cannot run past midnight — shorten it or start it earlier.");

        return (name, start, end);
    }

    /// <summary>Two periods cannot share a name or overlap on the clock.</summary>
    private static void EnsureNoClash(IEnumerable<TimetablePeriod> rows, string name, TimeSpan start,
        TimeSpan end, long? excludeId)
    {
        foreach (var p in rows)
        {
            if (p.Id == excludeId) continue;
            if (string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase))
                throw new ValidationException($"There is already a period called {p.Name}.");
            if (start < p.EndTime && p.StartTime < end)
                throw new ValidationException(
                    $"That overlaps {p.Name} ({Clock(p.StartTime)}–{Clock(p.EndTime)}). Periods cannot run at the same time.");
        }
    }

    /// <summary>Puts sort_order back in step with the clock after a period is added, moved or removed.</summary>
    private async Task ResequenceAsync(long schoolId, CancellationToken ct)
    {
        var rows = (await _repo.GetPeriodsAsync(schoolId, ct)).OrderBy(p => p.StartTime).ToList();
        for (var i = 0; i < rows.Count; i++)
        {
            if (rows[i].SortOrder != i + 1)
                await _repo.SetPeriodSortOrderAsync(schoolId, rows[i].Id, i + 1, ct);
            // The cells carry a copy of the time for the portals to render; re-stamp it, since
            // the period now at this position may not be the one that was here before.
            await _repo.SetSlotTimeLabelAsync(schoolId, i + 1, TimeLabel(rows[i]), ct);
        }
    }

    /// <summary>
    /// The school's periods in clock order, seeded on first use so a new school is not left with
    /// an empty grid. Ordering on the clock rather than on sort_order is what makes a period's
    /// position in the day a fact about its start time, not a second thing to keep in step.
    /// </summary>
    private async Task<List<TimetablePeriod>> SeededPeriodsAsync(long schoolId, CancellationToken ct)
    {
        var rows = await _repo.GetPeriodsAsync(schoolId, ct);
        if (rows.Count == 0)
        {
            await _repo.SeedDefaultPeriodsAsync(schoolId, ct);
            rows = await _repo.GetPeriodsAsync(schoolId, ct);
        }
        return rows.OrderBy(p => p.StartTime).ToList();
    }

    private static string Clock(TimeSpan t) => $"{t:hh\\:mm}";
    private static string TimeLabel(TimetablePeriod p) => $"{Clock(p.StartTime)}–{Clock(p.EndTime)}";

    /// <summary>Periods, seeded on first use so a new school is not left with an empty grid.</summary>
    private async Task<IReadOnlyList<TimetablePeriodDto>> PeriodsAsync(long schoolId, CancellationToken ct)
    {
        var rows = await SeededPeriodsAsync(schoolId, ct);
        // period_no is the running order, breaks included, so the grid columns line up with it.
        return rows.Select((p, i) => new TimetablePeriodDto(i + 1, p.Name, TimeLabel(p), p.IsBreak)).ToList();
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
