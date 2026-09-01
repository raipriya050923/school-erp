using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

public class SchoolService : ISchoolService
{
    private static readonly string[] ValidStatuses = { "pending", "active", "suspended", "terminated" };
    private static readonly string[] ValidCycles = { "monthly", "yearly" };
    private readonly ISchoolRepository _schools;
    private readonly IUserRepository _users;
    private readonly IPasswordHasher _hasher;
    private readonly IPlanRepository _plans;
    private readonly ISubscriptionRepository _subscriptions;
    private readonly AccountOptions _accountOptions;
    private readonly IAccountProvisioner _accounts;
    private readonly INotificationCenter _bell;
    private readonly ISubjectRepository _subjects;
    private readonly IFeeStructureRepository _feeHeads;
    private readonly ILeaveRepository _leave;
    private readonly IGeographyService _geography;

    public SchoolService(ISchoolRepository schools, IUserRepository users, IPasswordHasher hasher,
        IPlanRepository plans, ISubscriptionRepository subscriptions, AccountOptions accountOptions,
        IAccountProvisioner accounts, INotificationCenter bell, ISubjectRepository subjects,
        ILeaveRepository leave, IGeographyService geography, IFeeStructureRepository feeHeads)
    {
        _leave = leave;
        _geography = geography;
        _schools = schools;
        _users = users;
        _hasher = hasher;
        _plans = plans;
        _subscriptions = subscriptions;
        _accountOptions = accountOptions;
        _accounts = accounts;
        _bell = bell;
        _subjects = subjects;
        _feeHeads = feeHeads;
    }

    public async Task<IReadOnlyList<SchoolListItemDto>> ListAsync(string? search, string? status, CancellationToken ct = default)
    {
        var rows = await _schools.GetAllAsync(search, status, ct);
        // One lookup for every school rather than a query per row.
        var planNames = await _subscriptions.GetCurrentPlanNamesAsync(ct);
        var list = new List<SchoolListItemDto>(rows.Count);
        foreach (var s in rows)
        {
            var students = await _schools.GetStudentCountAsync(s.Id, ct);
            var plan = planNames.TryGetValue(s.Id, out var p) ? p : null;
            list.Add(new SchoolListItemDto(s.Id, s.SchoolCode, s.Name, s.City, s.Status, plan, students, s.CreatedAt));
        }
        return list;
    }

    public async Task<SchoolDetailDto?> GetAsync(long id, CancellationToken ct = default)
    {
        var s = await _schools.GetByIdAsync(id, ct);
        if (s is null) return null;
        // Schools onboarded before plans were mandatory have no subscription; the nulls let the
        // edit form show "No plan yet" and offer to assign one.
        var sub = await _subscriptions.GetCurrentBySchoolAsync(id, ct);
        var admin = await _users.GetSchoolAdminAsync(id, ct);
        // Only a configured demo password can be shown; a real one exists solely as a bcrypt hash.
        var demoPassword = admin is not null && !string.IsNullOrWhiteSpace(_accountOptions.FixedPassword)
            ? _accountOptions.FixedPassword
            : null;
        return new SchoolDetailDto(s.Id, s.SchoolCode, s.Name, s.Subdomain, s.Email, s.Phone,
            s.City, s.State, s.Country, s.PostalCode, s.AffiliationBoard, s.Currency, s.Timezone,
            s.Status, s.OnboardedAt, s.CreatedAt,
            sub?.PlanId, sub?.PlanName, sub?.BillingCycle, sub?.Status, sub?.EndDate,
            admin?.Username, admin?.Email, demoPassword,
            s.CountryId, s.StateId, s.CityId);
    }

    public async Task<CreateSchoolResultDto> CreateAsync(CreateSchoolDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Name))
            throw new ValidationException("School name is required.");
        if (await _schools.ExistsByNameAsync(dto.Name.Trim(), null, ct))
            throw new ValidationException($"A school named '{dto.Name}' already exists.");

        // The admin account uses the school's contact email, and password reset looks users up by
        // email across all tenants — so reject the duplicate here rather than create an account
        // that can never reset its own password.
        var adminEmail = dto.Email.Trim();
        if (await _users.GetByEmailAsync(adminEmail, ct) is not null)
            throw new ValidationException($"'{adminEmail}' is already used by another account. Use a different contact email.");

        var cycle = ValidCycles.Contains(dto.BillingCycle) ? dto.BillingCycle : "yearly";
        var plan = await _plans.GetByIdAsync(dto.PlanId, ct)
                   ?? throw new ValidationException("Choose a subscription plan for this school.");
        if (!plan.IsActive)
            throw new ValidationException($"The “{plan.Name}” plan is retired and cannot be assigned.");

        // The master is authoritative: this validates the triple hangs together and gives
        // back the names, which are mirrored into the legacy text columns.
        var place = await _geography.ResolveAsync(dto.CountryId, dto.StateId, dto.CityId, ct);

        var slug = Slugify(dto.Name);
        var school = new School
        {
            Name = dto.Name.Trim(),
            SchoolCode = GenerateCode(dto.Name),
            Subdomain = slug,
            Email = dto.Email.Trim(),
            Phone = dto.Phone.Trim(),
            City = place.CityName ?? dto.City,
            State = place.StateName ?? dto.State,
            Country = place.CountryName ?? dto.Country,
            PostalCode = dto.PostalCode,
            CountryId = place.CountryId,
            StateId = place.StateId,
            CityId = place.CityId,
            AffiliationBoard = dto.AffiliationBoard,
            // 'pending' is still accepted for legacy records but is no longer offered or defaulted:
            // onboarding issues working credentials and starts the subscription clock immediately,
            // so a new school is live from the moment it is created.
            Status = ValidStatuses.Contains(dto.Status) ? dto.Status : "active",
            OnboardedAt = dto.Status is "suspended" or "terminated" ? null : DateTime.UtcNow,
        };
        var schoolId = await _schools.CreateAsync(school, ct);
        // A school with no subjects cannot schedule an exam, and one with no leave types cannot
        // process a leave request, so start it with both default sets.
        await _subjects.SeedDefaultsAsync(schoolId, ct);
        // Subjects, exams and teacher assignments are all keyed by academic year, so a school
        // without one cannot use them — give it the standard three up front.
        await _schools.SeedDefaultAcademicYearsAsync(schoolId, ct);
        await _leave.SeedDefaultTypesAsync(schoolId, ct);
        // Fee heads too, so the school can price its classes on day one. Prices start empty on
        // purpose — there is no sensible default amount, and inventing one is what the old
        // hardcoded rate table did.
        await _feeHeads.SeedDefaultHeadsAsync(schoolId, ct);

        // Go through the shared provisioner so the admin login is minted exactly like teacher and
        // student logins — same username de-duplication, and the same Accounts:FixedPassword
        // shortcut. Doing this inline previously meant school admins silently ignored it.
        var fullName = Truncate($"{school.Name} Administrator", 150);
        var credentials = await _accounts.ProvisionAsync(
            schoolId, "school_admin", CredentialGenerator.UsernameStem(school.Name),
            fullName, adminEmail, school.Phone, ct);

        // Without this row the school is invisible to the Subscriptions page and to MRR, which is
        // why schools onboarded before this existed never showed up there.
        var startDate = DateTime.UtcNow.Date;
        var onTrial = plan.TrialDays > 0;
        var endDate = onTrial
            ? startDate.AddDays(plan.TrialDays)
            : (cycle == "monthly" ? startDate.AddMonths(1) : startDate.AddYears(1));
        await _subscriptions.CreateAsync(new SchoolSubscription
        {
            SchoolId = schoolId,
            PlanId = plan.Id,
            BillingCycle = cycle,
            StartDate = startDate,
            EndDate = endDate,
            // Price is locked at purchase time, so store the plan's price for the chosen cycle.
            Price = cycle == "monthly" ? plan.PriceMonthly : plan.PriceYearly,
            Status = onTrial ? "trial" : "active",
            AutoRenew = true,
        }, ct);

        await _bell.NotifyRoleAsync(null, "super_admin",
            "New school onboarded", $"{school.Name} ({school.SchoolCode}) joined on the {plan.Name} plan.",
            "school", "schools", schoolId, ct);

        return new CreateSchoolResultDto(schoolId, school.Name, school.SchoolCode, school.Subdomain,
            fullName, credentials.Username, adminEmail, credentials.TemporaryPassword,
            plan.Name, onTrial ? "trial" : "active", endDate);
    }

    public async Task<GeneratedCredentialsDto> ResetAdminPasswordAsync(long id, CancellationToken ct = default)
    {
        var school = await _schools.GetByIdAsync(id, ct) ?? throw new NotFoundException($"School {id} not found.");
        var admin = await _users.GetSchoolAdminAsync(id, ct)
                    ?? throw new ValidationException($"{school.Name} has no administrator login to reset.");

        // Honour the demo shortcut so a reset does not strand the tenant on a random password
        // while every other account in the environment shares a known one.
        var password = string.IsNullOrWhiteSpace(_accountOptions.FixedPassword)
            ? CredentialGenerator.Password()
            : _accountOptions.FixedPassword!;
        await _users.UpdatePasswordAsync(admin.Id, _hasher.Hash(password), ct);

        return new GeneratedCredentialsDto(admin.Id, admin.FullName, admin.Username, admin.Email, password);
    }

    private static string Truncate(string s, int max) => s.Length <= max ? s : s[..max];

    public async Task UpdateAsync(long id, UpdateSchoolDto dto, CancellationToken ct = default)
    {
        var s = await _schools.GetByIdAsync(id, ct) ?? throw new NotFoundException($"School {id} not found.");
        if (string.IsNullOrWhiteSpace(dto.Name))
            throw new ValidationException("School name is required.");
        if (await _schools.ExistsByNameAsync(dto.Name.Trim(), id, ct))
            throw new ValidationException($"A school named '{dto.Name}' already exists.");

        var place = await _geography.ResolveAsync(dto.CountryId, dto.StateId, dto.CityId, ct);

        s.Name = dto.Name.Trim();
        s.Email = dto.Email.Trim();
        s.Phone = dto.Phone.Trim();
        s.City = place.CityName ?? dto.City;
        s.State = place.StateName ?? dto.State;
        s.Country = place.CountryName ?? dto.Country;
        s.PostalCode = dto.PostalCode;
        s.CountryId = place.CountryId;
        s.StateId = place.StateId;
        s.CityId = place.CityId;
        s.AffiliationBoard = dto.AffiliationBoard;
        if (ValidStatuses.Contains(dto.Status)) s.Status = dto.Status;
        await _schools.UpdateAsync(s, ct);

        if (dto.PlanId > 0) await ApplyPlanAsync(id, dto.PlanId, dto.BillingCycle, ct);
    }

    /// <summary>
    /// Moves a school onto the given plan: switches its live subscription, or opens the first one
    /// for a school onboarded before plans were mandatory (which is what kept those schools off
    /// the Subscriptions page entirely).
    /// </summary>
    private async Task ApplyPlanAsync(long schoolId, long planId, string billingCycle, CancellationToken ct)
    {
        var cycle = ValidCycles.Contains(billingCycle) ? billingCycle : "yearly";
        var plan = await _plans.GetByIdAsync(planId, ct)
                   ?? throw new ValidationException("That subscription plan no longer exists.");
        if (!plan.IsActive)
            throw new ValidationException($"The “{plan.Name}” plan is retired and cannot be assigned.");

        var price = cycle == "monthly" ? plan.PriceMonthly : plan.PriceYearly;
        var current = await _subscriptions.GetCurrentBySchoolAsync(schoolId, ct);
        if (current is not null)
        {
            // Keep the running status and period; only the plan, cycle and locked price change.
            if (current.PlanId == planId && current.BillingCycle == cycle) return;
            await _subscriptions.UpdatePlanAsync(current.Id, planId, cycle, price, ct);
            return;
        }

        var startDate = DateTime.UtcNow.Date;
        var onTrial = plan.TrialDays > 0;
        await _subscriptions.CreateAsync(new SchoolSubscription
        {
            SchoolId = schoolId,
            PlanId = plan.Id,
            BillingCycle = cycle,
            StartDate = startDate,
            EndDate = onTrial ? startDate.AddDays(plan.TrialDays)
                              : (cycle == "monthly" ? startDate.AddMonths(1) : startDate.AddYears(1)),
            Price = price,
            Status = onTrial ? "trial" : "active",
            AutoRenew = true,
        }, ct);
    }

    public async Task ChangeStatusAsync(long id, string status, CancellationToken ct = default)
    {
        if (!ValidStatuses.Contains(status))
            throw new ValidationException($"Invalid status '{status}'.");
        _ = await _schools.GetByIdAsync(id, ct) ?? throw new NotFoundException($"School {id} not found.");
        await _schools.UpdateStatusAsync(id, status, ct);
    }

    private static string Slugify(string name) =>
        new string(name.ToLowerInvariant().Select(c => char.IsLetterOrDigit(c) ? c : '-').ToArray())
            .Trim('-').Replace("--", "-");

    private static string GenerateCode(string name)
    {
        var initials = new string(name.Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Select(w => char.ToUpperInvariant(w[0])).Where(char.IsLetter).ToArray());
        if (initials.Length < 3) initials = (initials + "XXX")[..3];
        else initials = initials[..3];
        return $"{initials}{DateTime.UtcNow:HHmmss}";
    }
}
