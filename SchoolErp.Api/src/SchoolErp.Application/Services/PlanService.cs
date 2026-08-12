using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Plans;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

public class PlanService : IPlanService
{
    private readonly IPlanRepository _plans;

    public PlanService(IPlanRepository plans) => _plans = plans;

    public async Task<IReadOnlyList<PlanDto>> ListAsync(CancellationToken ct = default)
    {
        var rows = await _plans.GetAllAsync(ct);
        var list = new List<PlanDto>(rows.Count);
        foreach (var p in rows)
        {
            var subs = await _plans.GetSubscriberCountAsync(p.Id, ct);
            list.Add(Map(p, subs));
        }
        return list;
    }

    public async Task<PlanDto?> GetAsync(long id, CancellationToken ct = default)
    {
        var p = await _plans.GetByIdAsync(id, ct);
        if (p is null) return null;
        var subs = await _plans.GetSubscriberCountAsync(p.Id, ct);
        return Map(p, subs);
    }

    public async Task<long> CreateAsync(CreatePlanDto dto, CancellationToken ct = default)
    {
        Validate(dto.Name, dto.PriceMonthly, dto.PriceYearly);
        if (await _plans.ExistsByNameAsync(dto.Name.Trim(), null, ct))
            throw new ValidationException($"A plan named '{dto.Name}' already exists.");

        var plan = new SubscriptionPlan
        {
            Name = dto.Name.Trim(),
            Slug = dto.Name.Trim().ToLowerInvariant().Replace(' ', '-'),
            Description = dto.Description,
            PriceMonthly = dto.PriceMonthly,
            PriceYearly = dto.PriceYearly,
            MaxStudents = dto.MaxStudents,
            MaxStaff = dto.MaxStaff,
            TrialDays = dto.TrialDays,
            IsActive = true,
        };
        return await _plans.CreateAsync(plan, ct);
    }

    public async Task UpdateAsync(long id, UpdatePlanDto dto, CancellationToken ct = default)
    {
        var p = await _plans.GetByIdAsync(id, ct) ?? throw new NotFoundException($"Plan {id} not found.");
        if (dto.PriceMonthly < 0 || dto.PriceYearly < 0)
            throw new ValidationException("Prices cannot be negative.");

        p.Description = dto.Description;
        p.PriceMonthly = dto.PriceMonthly;
        p.PriceYearly = dto.PriceYearly;
        p.MaxStudents = dto.MaxStudents;
        p.MaxStaff = dto.MaxStaff;
        p.TrialDays = dto.TrialDays;
        await _plans.UpdateAsync(p, ct);
    }

    public async Task SetActiveAsync(long id, bool isActive, CancellationToken ct = default)
    {
        _ = await _plans.GetByIdAsync(id, ct) ?? throw new NotFoundException($"Plan {id} not found.");
        await _plans.SetActiveAsync(id, isActive, ct);
    }

    private static void Validate(string name, decimal monthly, decimal yearly)
    {
        if (string.IsNullOrWhiteSpace(name)) throw new ValidationException("Plan name is required.");
        if (monthly < 0 || yearly < 0) throw new ValidationException("Prices cannot be negative.");
    }

    private static PlanDto Map(SubscriptionPlan p, int subscribers) => new(
        p.Id, p.Name, p.Slug, p.Description, p.PriceMonthly, p.PriceYearly,
        p.MaxStudents, p.MaxStaff, p.TrialDays, p.IsActive, subscribers);
}
