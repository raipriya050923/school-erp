using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

public class FeeStructureService : IFeeStructureService
{
    /// <summary>Mirrors the fee_structures.frequency enum; anything else is rejected.</summary>
    private static readonly string[] ValidFrequencies = { "one_time", "monthly", "quarterly", "half_yearly", "yearly" };

    private readonly IFeeStructureRepository _repo;
    private readonly IClassRepository _classes;
    private readonly IAcademicYearRepository _years;
    private readonly ICurrentSchool _school;

    public FeeStructureService(IFeeStructureRepository repo, IClassRepository classes,
        IAcademicYearRepository years, ICurrentSchool school)
    {
        _repo = repo;
        _classes = classes;
        _years = years;
        _school = school;
    }

    /* ============================ heads ============================ */

    public async Task<IReadOnlyList<FeeHeadDto>> ListHeadsAsync(CancellationToken ct = default)
    {
        var heads = await HeadsAsync(ct);
        var year = await CurrentYearAsync(ct);
        var cells = year is null
            ? Array.Empty<FeeStructureCell>()
            : (await _repo.GetCellsAsync(_school.SchoolId, year.Id, ct)).ToArray();
        return heads.Select(h => ToDto(h, cells.Count(c => c.FeeTypeId == h.Id))).ToList();
    }

    public async Task<long> CreateHeadAsync(SaveFeeHeadDto dto, CancellationToken ct = default)
    {
        var name = ValidateName(dto);
        if (await _repo.HeadNameExistsAsync(_school.SchoolId, name, null, ct))
            throw new ValidationException($"A fee head called “{name}” already exists.");

        return await _repo.CreateHeadAsync(new FeeHead
        {
            SchoolId = _school.SchoolId,
            Name = name,
            Description = Trim(dto.Description),
            Frequency = Frequency(dto.Frequency, "monthly"),
            IsRefundable = dto.IsRefundable,
            IsActive = true,
        }, ct);
    }

    public async Task UpdateHeadAsync(long id, SaveFeeHeadDto dto, CancellationToken ct = default)
    {
        var name = ValidateName(dto);
        var head = await _repo.GetHeadAsync(_school.SchoolId, id, ct)
                   ?? throw new NotFoundException($"Fee head {id} not found.");
        if (await _repo.HeadNameExistsAsync(_school.SchoolId, name, id, ct))
            throw new ValidationException($"A fee head called “{name}” already exists.");

        head.Name = name;
        head.Description = Trim(dto.Description);
        head.Frequency = Frequency(dto.Frequency, head.Frequency);
        head.IsRefundable = dto.IsRefundable;
        await _repo.UpdateHeadAsync(head, ct);
    }

    public async Task SetHeadActiveAsync(long id, bool isActive, CancellationToken ct = default)
    {
        _ = await _repo.GetHeadAsync(_school.SchoolId, id, ct)
            ?? throw new NotFoundException($"Fee head {id} not found.");
        await _repo.SetHeadActiveAsync(_school.SchoolId, id, isActive, ct);
    }

    /* ============================ grid ============================ */

    public async Task<FeeStructureGridDto> GridAsync(long? academicYearId, CancellationToken ct = default)
    {
        var year = academicYearId is { } id
            ? await _years.GetByIdAsync(_school.SchoolId, id, ct)
              ?? throw new NotFoundException($"Academic year {id} not found.")
            : await CurrentYearAsync(ct);

        var heads = await HeadsAsync(ct);
        var classes = await _classes.GetAllWithSectionsAsync(_school.SchoolId, ct);
        var cells = year is null
            ? new List<FeeStructureCell>()
            : (await _repo.GetCellsAsync(_school.SchoolId, year.Id, ct)).ToList();

        // What a single monthly invoice will come to for each class — the number the admin is
        // really setting, and the one that ends up on the invoice.
        var monthly = classes.ToDictionary(
            c => c.Name,
            c => cells.Where(x => x.ClassId == c.Id && x.Frequency == "monthly").Sum(x => x.Amount));

        return new FeeStructureGridDto(
            year?.Id,
            year?.Name,
            classes.Select(c => new FeeStructureClassDto(c.Id, c.Name)).ToList(),
            heads.Select(h => ToDto(h, cells.Count(c => c.FeeTypeId == h.Id))).ToList(),
            cells.Select(c => new FeeStructureCellDto(c.ClassId, c.FeeTypeId, c.Amount)).ToList(),
            monthly);
    }

    public async Task SaveGridAsync(SaveFeeStructureDto dto, CancellationToken ct = default)
    {
        var year = dto.AcademicYearId is { } id
            ? await _years.GetByIdAsync(_school.SchoolId, id, ct)
              ?? throw new NotFoundException($"Academic year {id} not found.")
            : await CurrentYearAsync(ct)
              ?? throw new ValidationException("Set a current academic year before pricing fees.");

        if (dto.Cells.Count == 0) return;
        if (dto.Cells.Any(c => c.Amount < 0))
            throw new ValidationException("Fee amounts cannot be negative.");

        // Both ids are checked against this school before anything is written; SaveCellAsync
        // re-checks the head, but the class only exists as a foreign key, so verify it here.
        var classIds = (await _classes.GetAllWithSectionsAsync(_school.SchoolId, ct)).Select(c => c.Id).ToHashSet();
        var headIds = (await _repo.GetHeadsAsync(_school.SchoolId, ct)).Select(h => h.Id).ToHashSet();
        foreach (var cell in dto.Cells)
        {
            if (!classIds.Contains(cell.ClassId)) throw new NotFoundException($"Class {cell.ClassId} not found.");
            if (!headIds.Contains(cell.HeadId)) throw new NotFoundException($"Fee head {cell.HeadId} not found.");
        }

        foreach (var cell in dto.Cells)
            await _repo.SaveCellAsync(_school.SchoolId, year.Id, cell.ClassId, cell.HeadId, cell.Amount, ct);
    }

    public async Task<int> CopyYearAsync(CopyFeeStructureDto dto, CancellationToken ct = default)
    {
        if (dto.FromAcademicYearId == dto.ToAcademicYearId)
            throw new ValidationException("Pick two different academic years.");
        _ = await _years.GetByIdAsync(_school.SchoolId, dto.FromAcademicYearId, ct)
            ?? throw new NotFoundException("The year to copy from was not found.");
        _ = await _years.GetByIdAsync(_school.SchoolId, dto.ToAcademicYearId, ct)
            ?? throw new NotFoundException("The year to copy into was not found.");
        return await _repo.CopyYearAsync(_school.SchoolId, dto.FromAcademicYearId, dto.ToAcademicYearId, ct);
    }

    /* ============================ helpers ============================ */

    /// <summary>
    /// Heads for this school, seeding the defaults the first time. Schools created before fee
    /// heads existed have none, which would leave both this screen and the invoice run with
    /// nothing to work from.
    /// </summary>
    private async Task<IReadOnlyList<FeeHead>> HeadsAsync(CancellationToken ct)
    {
        var heads = await _repo.GetHeadsAsync(_school.SchoolId, ct);
        if (heads.Count > 0) return heads;
        await _repo.SeedDefaultHeadsAsync(_school.SchoolId, ct);
        return await _repo.GetHeadsAsync(_school.SchoolId, ct);
    }

    private async Task<AcademicYear?> CurrentYearAsync(CancellationToken ct)
    {
        var years = await _years.GetAllAsync(_school.SchoolId, ct);
        return years.FirstOrDefault(y => y.IsCurrent) ?? years.FirstOrDefault();
    }

    private static FeeHeadDto ToDto(FeeHead h, int inUse) =>
        new(h.Id, h.Name, h.Description, h.Frequency, h.IsRefundable, h.IsActive, inUse);

    private static string ValidateName(SaveFeeHeadDto dto)
    {
        var name = dto.Name?.Trim() ?? "";
        if (name.Length == 0) throw new ValidationException("Fee head name is required.");
        return name;
    }

    private static string Frequency(string? value, string fallback) =>
        ValidFrequencies.Contains(value) ? value! : fallback;

    private static string? Trim(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
