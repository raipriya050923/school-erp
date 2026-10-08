using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services.Admin;

/// <summary>
/// Which subjects a class studies, and who teaches each of them to each section.
/// Everything is scoped to the school's current academic year: assignments are per year, so a
/// new year starts with a clean grid rather than inheriting last year's staffing.
/// </summary>
public class CurriculumService : ICurriculumService
{
    private readonly ICurriculumRepository _repo;
    private readonly IClassRepository _classes;
    private readonly ISubjectRepository _subjects;
    private readonly ITeacherRepository _teachers;
    private readonly ISchoolRepository _schools;
    private readonly ITimetableRepository _timetable;
    private readonly ICurrentSchool _school;

    public CurriculumService(ICurriculumRepository repo, IClassRepository classes,
        ISubjectRepository subjects, ITeacherRepository teachers, ISchoolRepository schools,
        ITimetableRepository timetable, ICurrentSchool school)
    {
        _repo = repo;
        _classes = classes;
        _subjects = subjects;
        _teachers = teachers;
        _schools = schools;
        _timetable = timetable;
        _school = school;
    }

    public async Task<IReadOnlyList<ClassSubjectsDto>> SubjectsByClassAsync(CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var year = await RequireYearAsync(sid, ct);
        var classes = await _classes.GetAllWithSectionsAsync(sid, ct);

        var result = new List<ClassSubjectsDto>();
        foreach (var c in classes)
        {
            var chosen = await _repo.GetClassSubjectsAsync(sid, year.Id, c.Id, ct);
            result.Add(new ClassSubjectsDto(c.Id, c.Name,
                chosen.Select(x => x.SubjectName ?? "").Where(n => n.Length > 0).OrderBy(n => n).ToList()));
        }
        return result;
    }

    public async Task<ClassCurriculumDto> GetAsync(long classId, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var year = await RequireYearAsync(sid, ct);

        var cls = await _classes.GetByIdAsync(sid, classId, ct)
                  ?? throw new NotFoundException($"Class {classId} not found.");
        var withSections = (await _classes.GetAllWithSectionsAsync(sid, ct)).FirstOrDefault(c => c.Id == classId);
        var sections = withSections?.Sections ?? new();

        var allSubjects = await _subjects.GetAllAsync(sid, ct);
        var chosen = await _repo.GetClassSubjectsAsync(sid, year.Id, classId, ct);
        var chosenIds = chosen.Select(c => c.SubjectId).ToHashSet();
        var assignedIds = (await _repo.GetAssignedSubjectIdsAsync(year.Id, classId, ct)).ToHashSet();

        var options = allSubjects
            .Where(s => s.IsActive || chosenIds.Contains(s.Id))   // keep a retired subject visible while still in use
            .Select(s => new ClassSubjectOptionDto(s.Id, s.Name, chosenIds.Contains(s.Id), assignedIds.Contains(s.Id)))
            .ToList();

        var assignments = await _repo.GetAssignmentsForClassAsync(sid, year.Id, classId, ct);
        var grid = chosen.Select(cs => new AssignmentRowDto(
            cs.SubjectId,
            cs.SubjectName ?? "",
            sections.Select(sec =>
            {
                var hit = assignments.FirstOrDefault(a => a.SectionId == sec.Id && a.SubjectId == cs.SubjectId);
                return new AssignmentCellDto(sec.Id, sec.Name, hit?.StaffId, hit?.TeacherName);
            }).ToList())).ToList();

        return new ClassCurriculumDto(cls.Id, cls.Name, year.Name, options, grid);
    }

    public async Task SetSubjectsAsync(long classId, SetClassSubjectsDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var year = await RequireYearAsync(sid, ct);
        _ = await _classes.GetByIdAsync(sid, classId, ct)
            ?? throw new NotFoundException($"Class {classId} not found.");

        // Dropping a subject that still has a teacher would orphan that assignment, so say so
        // rather than deleting silently.
        var assigned = await _repo.GetAssignedSubjectIdsAsync(year.Id, classId, ct);
        var removed = assigned.Except(dto.SubjectIds).ToList();
        if (removed.Count > 0)
        {
            var names = (await _subjects.GetAllAsync(sid, ct))
                .Where(s => removed.Contains(s.Id)).Select(s => s.Name);
            throw new ValidationException(
                $"Unassign the teachers for {string.Join(", ", names)} before removing the subject from this class.");
        }

        await _repo.SetClassSubjectsAsync(sid, year.Id, classId, dto.SubjectIds, ct);
    }

    public async Task AssignAsync(SaveAssignmentDto dto, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var year = await RequireYearAsync(sid, ct);

        var cls = (await _classes.GetAllWithSectionsAsync(sid, ct)).FirstOrDefault(c => c.Id == dto.ClassId)
                  ?? throw new NotFoundException($"Class {dto.ClassId} not found.");
        if (cls.Sections.All(s => s.Id != dto.SectionId))
            throw new ValidationException("That section does not belong to this class.");

        var subjects = await _repo.GetClassSubjectsAsync(sid, year.Id, dto.ClassId, ct);
        if (subjects.All(s => s.SubjectId != dto.SubjectId))
            throw new ValidationException("Add the subject to this class before assigning a teacher to it.");

        if (dto.StaffId is { } staffId)
        {
            var teacher = await _teachers.GetByIdAsync(sid, staffId, ct)
                          ?? throw new ValidationException("That teacher no longer exists at this school.");
            if (teacher.Status is not "active")
                throw new ValidationException($"{teacher.FirstName} {teacher.LastName} is not active and cannot be assigned.");
        }

        // Periods already timetabled for this subject name the old teacher. Repoint them, but
        // only if that does not double-book the new one — otherwise changing an assignment could
        // quietly create the clash the timetable screens work to prevent.
        var section = cls.Sections.First(s => s.Id == dto.SectionId);
        var subjectName = subjects.First(s => s.SubjectId == dto.SubjectId).SubjectName ?? "";
        var scheduled = await _timetable.GetForSectionSubjectAsync(sid, cls.Name, section.Name, subjectName, ct);

        if (dto.StaffId is { } newStaff)
        {
            foreach (var slot in scheduled)
            {
                var clash = await _timetable.FindTeacherClashAsync(sid, newStaff, slot.DayOfWeek,
                    slot.PeriodNo, cls.Name, section.Name, ct);
                if (clash is not null)
                    throw new ValidationException(
                        $"{subjectName} is timetabled for {cls.Name}-{section.Name} in period {slot.PeriodNo}, " +
                        $"when that teacher already takes {clash.ClassLabel}-{clash.SectionLabel}. " +
                        "Move one of those periods first.");
            }
        }

        await _repo.AssignAsync(sid, year.Id, dto.ClassId, dto.SectionId, dto.SubjectId, dto.StaffId, ct);
        if (scheduled.Count > 0)
            await _timetable.RetargetSlotTeacherAsync(sid, cls.Name, section.Name, subjectName, dto.StaffId, ct);
    }

    /// <summary>
    /// Clears the whole grid in one go — the alternative is setting a dozen dropdowns to
    /// unassigned by hand. Subjects the class studies are left alone.
    /// </summary>
    public async Task<int> ClearAssignmentsAsync(long classId, CancellationToken ct = default)
    {
        var sid = _school.SchoolId;
        var year = await RequireYearAsync(sid, ct);
        _ = await _classes.GetByIdAsync(sid, classId, ct)
            ?? throw new NotFoundException($"Class {classId} not found.");
        var cleared = await _repo.ClearAssignmentsForClassAsync(sid, year.Id, classId, ct);

        // Leave no timetabled period still naming a teacher who is no longer assigned to it.
        var cls = (await _classes.GetAllWithSectionsAsync(sid, ct)).First(c => c.Id == classId);
        var subjects = await _repo.GetClassSubjectsAsync(sid, year.Id, classId, ct);
        foreach (var section in cls.Sections)
            foreach (var subject in subjects)
                await _timetable.RetargetSlotTeacherAsync(sid, cls.Name, section.Name,
                    subject.SubjectName ?? "", null, ct);

        return cleared;
    }

    private async Task<(long Id, string Name)> RequireYearAsync(long schoolId, CancellationToken ct)
    {
        var id = await _schools.GetCurrentAcademicYearIdAsync(schoolId, ct)
                 ?? throw new ValidationException(
                     "This school has no academic year set up, so subjects cannot be scheduled yet.");
        var name = await _schools.GetCurrentAcademicYearAsync(schoolId, ct) ?? "";
        return (id, name);
    }
}
