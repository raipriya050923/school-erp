using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

/// <summary>
/// Transport pricing: a scale of distance bands per academic year, and one distance per student.
///
/// Transport is the one head where a class price is the wrong answer. Two children in the same
/// class can live a street apart and twelve kilometres apart, and a third walks to school and
/// should see no bus charge at all. So the head is marked <c>distance</c>, its column on the Fee
/// Structure grid stops being editable, and the amount is resolved per student here.
/// </summary>
public class TransportService : ITransportService
{
    /// <summary>
    /// A school with more riders than this is beyond what one editable page can carry — the
    /// screen would be unusable long before the query was slow. Nothing is silently dropped:
    /// the roster is read in full and the cap only guards against an unbounded read.
    /// </summary>
    private const int MaxStudents = 5000;

    private readonly ITransportRepository _repo;
    private readonly IFeeStructureRepository _fees;
    private readonly IStudentRepository _students;
    private readonly IAcademicYearRepository _years;
    private readonly ICurrentSchool _school;

    public TransportService(ITransportRepository repo, IFeeStructureRepository fees,
        IStudentRepository students, IAcademicYearRepository years, ICurrentSchool school)
    {
        _repo = repo;
        _fees = fees;
        _students = students;
        _years = years;
        _school = school;
    }

    /* ============================ the screen ============================ */

    public async Task<TransportGridDto> GridAsync(long? academicYearId, CancellationToken ct = default)
    {
        var year = await ResolveYearAsync(academicYearId, ct);
        var head = await DistanceHeadAsync(ct);

        var slabs = year is null || head is null
            ? new List<TransportSlab>()
            : (await _repo.GetSlabsAsync(_school.SchoolId, year.Id, head.Id, ct)).ToList();

        var (roster, _) = await _students.GetPageAsync(_school.SchoolId, null, null, null, null, 0, MaxStudents, ct);
        var assignments = (await _repo.GetAssignmentsAsync(_school.SchoolId, ct))
            .ToDictionary(a => a.StudentId);

        var rows = roster
            .Where(s => s.Status == "active")
            .OrderBy(s => s.ClassName).ThenBy(s => s.SectionName).ThenBy(s => s.FirstName)
            .Select(s =>
            {
                assignments.TryGetValue(s.Id, out var a);
                var fee = TransportPricing.Resolve(a, slabs);
                return new TransportStudentDto(
                    s.Id, $"{s.FirstName} {s.LastName}".Trim(), s.AdmissionNo, s.ClassName, s.SectionName,
                    a?.IsActive ?? false, a?.DistanceKm, a?.PickupPoint, a?.AmountOverride, a?.Note,
                    fee.Amount, StatusName(fee.Status), fee.MatchedSlabKm);
            })
            .ToList();

        // Rider counts are per band so the school can see the shape of its own scale — a band
        // nobody falls into is usually a ceiling set in the wrong place.
        var slabDtos = new List<TransportSlabDto>();
        decimal floor = 0m;
        foreach (var s in slabs.OrderBy(x => x.UpToKm))
        {
            var riders = rows.Count(r => r.MatchedSlabKm == s.UpToKm);
            slabDtos.Add(new TransportSlabDto(s.Id, floor, s.UpToKm, s.Amount, riders));
            floor = s.UpToKm;
        }

        var summary = new TransportSummaryDto(
            Riders: rows.Count(r => r.UsesTransport),
            NotRiding: rows.Count(r => !r.UsesTransport),
            NeedsDistance: rows.Count(r => r.Status is "no_distance" or "no_slabs"),
            BeyondSlabs: rows.Count(r => r.Status == "beyond_slabs"),
            MonthlyTotal: rows.Sum(r => r.Amount));

        return new TransportGridDto(
            year?.Id, year?.Name, head?.Id, head?.Name, head?.Frequency, slabDtos, rows, summary);
    }

    /* ============================ bands ============================ */

    public async Task SaveSlabsAsync(SaveTransportSlabsDto dto, CancellationToken ct = default)
    {
        var year = await ResolveYearAsync(dto.AcademicYearId, ct)
                   ?? throw new ValidationException("Set a current academic year before pricing transport.");
        var head = await DistanceHeadAsync(ct)
                   ?? throw new ValidationException(
                       "No fee head is priced by distance. Edit a head on Fee Structure and set it to Per student (distance).");

        var slabs = new List<TransportSlab>();
        var seen = new HashSet<decimal>();
        foreach (var s in dto.Slabs)
        {
            if (s.UpToKm <= 0) throw new ValidationException("Each band needs a distance greater than zero.");
            if (s.UpToKm > 500) throw new ValidationException("A band above 500 km is not a school bus route.");
            if (s.Amount < 0) throw new ValidationException("A band amount cannot be negative.");
            // Two bands ending at the same distance would make the fare for that distance a
            // question of row order. The unique key would reject the second anyway; this says why.
            if (!seen.Add(s.UpToKm))
                throw new ValidationException($"There are two bands ending at {s.UpToKm:0.##} km.");

            slabs.Add(new TransportSlab
            {
                SchoolId = _school.SchoolId,
                AcademicYearId = year.Id,
                FeeTypeId = head.Id,
                UpToKm = decimal.Round(s.UpToKm, 2),
                Amount = decimal.Round(s.Amount, 2),
            });
        }

        await _repo.ReplaceSlabsAsync(_school.SchoolId, year.Id, head.Id,
            slabs.OrderBy(s => s.UpToKm).ToList(), ct);
    }

    public async Task<int> CopySlabsAsync(CopyFeeStructureDto dto, CancellationToken ct = default)
    {
        if (dto.FromAcademicYearId == dto.ToAcademicYearId)
            throw new ValidationException("Pick two different academic years.");
        _ = await _years.GetByIdAsync(_school.SchoolId, dto.FromAcademicYearId, ct)
            ?? throw new NotFoundException("The year to copy from was not found.");
        _ = await _years.GetByIdAsync(_school.SchoolId, dto.ToAcademicYearId, ct)
            ?? throw new NotFoundException("The year to copy into was not found.");
        var head = await DistanceHeadAsync(ct)
                   ?? throw new ValidationException("No fee head is priced by distance.");
        return await _repo.CopySlabsAsync(
            _school.SchoolId, dto.FromAcademicYearId, dto.ToAcademicYearId, head.Id, ct);
    }

    /* ============================ riders ============================ */

    public async Task<int> SaveStudentsAsync(SaveTransportStudentsDto dto, CancellationToken ct = default)
    {
        if (dto.Students.Count == 0) return 0;

        var saved = 0;
        foreach (var s in dto.Students)
        {
            if (s.DistanceKm is { } km && (km < 0 || km > 500))
                throw new ValidationException("A distance must be between 0 and 500 km.");
            if (s.AmountOverride is < 0)
                throw new ValidationException("An agreed amount cannot be negative.");

            // Counted only when a row was actually written: a student id belonging to another
            // school matches nothing, and reporting it as saved would be a lie the admin acts on.
            if (await _repo.SaveAssignmentAsync(new StudentTransport
            {
                SchoolId = _school.SchoolId,
                StudentId = s.StudentId,
                IsActive = s.UsesTransport,
                // A student taken off the bus keeps their distance and pickup point: they are
                // facts about where the child lives, and re-typing them next term is how they
                // end up wrong. Only the agreed amount is dropped, because that was a deal for
                // a service they are no longer taking.
                DistanceKm = s.DistanceKm,
                PickupPoint = Trim(s.PickupPoint),
                AmountOverride = s.UsesTransport ? s.AmountOverride : null,
                Note = Trim(s.Note),
            }, ct)) saved++;
        }
        return saved;
    }

    /* ============================ helpers ============================ */

    /// <summary>
    /// The head whose amount comes from distance. Exactly one is expected — a school with two
    /// would be billing transport twice — so the first by name wins and the rest are ignored
    /// rather than the screen refusing to load.
    /// </summary>
    private async Task<FeeHead?> DistanceHeadAsync(CancellationToken ct)
    {
        var heads = await _fees.GetHeadsAsync(_school.SchoolId, ct);
        if (heads.Count == 0)
        {
            await _fees.SeedDefaultHeadsAsync(_school.SchoolId, ct);
            heads = await _fees.GetHeadsAsync(_school.SchoolId, ct);
        }
        return heads.FirstOrDefault(h => h.IsActive && h.PricingMode == "distance");
    }

    private async Task<AcademicYear?> ResolveYearAsync(long? id, CancellationToken ct)
    {
        if (id is { } wanted)
            return await _years.GetByIdAsync(_school.SchoolId, wanted, ct)
                   ?? throw new NotFoundException($"Academic year {wanted} not found.");
        var years = await _years.GetAllAsync(_school.SchoolId, ct);
        return years.FirstOrDefault(y => y.IsCurrent) ?? years.FirstOrDefault();
    }

    private static string StatusName(TransportFeeStatus status) => status switch
    {
        TransportFeeStatus.Priced => "priced",
        TransportFeeStatus.NotRiding => "not_riding",
        TransportFeeStatus.NoDistance => "no_distance",
        TransportFeeStatus.BeyondSlabs => "beyond_slabs",
        _ => "no_slabs",
    };

    private static string? Trim(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
