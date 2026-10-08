using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Billing;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services;

/// <summary>
/// What a school's plan currently entitles it to, in one place.
///
/// Three rules depend on this and must not disagree: login is refused once the
/// subscription has lapsed, admissions stop at the plan's student cap, and the
/// admin console warns before either happens. Working them out separately in
/// three services is how a school ends up locked out of a plan the dashboard
/// still shows as active.
/// </summary>
public class SubscriptionGuard : ISubscriptionGuard
{
    /// <summary>
    /// How long before expiry the admin console starts warning. The user asked
    /// for a week's notice.
    /// </summary>
    public const int WarningWindowDays = 7;

    private readonly ISubscriptionRepository _subscriptions;
    private readonly IPlanRepository _plans;
    private readonly IStudentRepository _students;
    private readonly ISchoolRepository _schools;

    public SubscriptionGuard(ISubscriptionRepository subscriptions, IPlanRepository plans,
        IStudentRepository students, ISchoolRepository schools)
    {
        _subscriptions = subscriptions;
        _plans = plans;
        _students = students;
        _schools = schools;
    }

    public async Task<SubscriptionStatusDto> GetStatusAsync(long schoolId, CancellationToken ct = default)
    {
        var sub = await _subscriptions.GetLatestBySchoolAsync(schoolId, ct);

        // A school onboarded before plans existed has no subscription row. It is
        // left unrestricted rather than locked out of a product it already paid for.
        if (sub is null)
        {
            var seats = await _students.CountAsync(schoolId, ct);
            return new SubscriptionStatusDto(null, null, "none", false, null, null,
                seats, null, false, false, null);
        }

        var plan = await _plans.GetByIdAsync(sub.PlanId, ct);
        var studentCount = await _students.CountAsync(schoolId, ct);

        // Dates are the authority, not the stored word. `status` is only updated when
        // somebody edits the subscription, so a trial that ran out three weeks ago
        // still reads "trial" — which is exactly why lapsed schools kept signing in.
        var today = DateTime.UtcNow.Date;
        var endDate = sub.EndDate.Date;
        var daysRemaining = (int)(endDate - today).TotalDays;

        var isCancelled = sub.Status is "cancelled" or "expired";
        var isLapsed = isCancelled || sub.Status == "past_due" || endDate < today;
        var isTrial = sub.Status == "trial";

        var maxStudents = plan?.MaxStudents;
        var atCap = maxStudents is { } cap && studentCount >= cap;

        return new SubscriptionStatusDto(
            sub.PlanId, plan?.Name, sub.Status, isTrial, sub.EndDate, daysRemaining,
            studentCount, maxStudents, atCap, isLapsed,
            LapseReason(sub.Status, endDate, today));
    }

    /// <summary>
    /// Refuses a login for a school whose subscription has lapsed. Called for
    /// every role except platform staff, who must stay able to sign in and fix it.
    /// </summary>
    public async Task EnsureUsableAsync(long schoolId, CancellationToken ct = default)
    {
        var school = await _schools.GetByIdAsync(schoolId, ct)
                     ?? throw new ValidationException("This school no longer exists. Contact support.");
        if (school.Status == "suspended")
            throw new ValidationException("This school is suspended. Contact your platform administrator.");
        if (school.Status == "terminated")
            throw new ValidationException("This school's account has been closed. Contact your platform administrator.");

        var status = await GetStatusAsync(schoolId, ct);
        if (status.IsLapsed)
            throw new ValidationException(status.LapseReason ?? "This school's subscription has ended.");
    }

    /// <summary>
    /// Refuses an admission that would take the school past its plan's seat count.
    /// </summary>
    /// <remarks>
    /// Deliberately a "no new admissions" rule, not a "your data is over the limit"
    /// rule: several schools are already above the cap of the plan they are on, and
    /// blocking their existing students would take away records they depend on.
    /// The cap only stops the count growing.
    /// </remarks>
    public async Task EnsureCanAdmitStudentAsync(long schoolId, CancellationToken ct = default)
    {
        var status = await GetStatusAsync(schoolId, ct);
        if (status.MaxStudents is not { } cap) return;   // unlimited plan
        if (status.StudentCount < cap) return;

        throw new ValidationException(
            $"The {status.PlanName ?? "current"} plan allows {cap} students and this school " +
            $"already has {status.StudentCount}. Upgrade the plan to admit more.");
    }

    private static string? LapseReason(string status, DateTime endDate, DateTime today) => status switch
    {
        "cancelled" => "This school's subscription was cancelled. Contact your platform administrator.",
        "expired" => "This school's subscription has ended. Contact your platform administrator.",
        "past_due" => "This school's subscription is unpaid. Contact your platform administrator to restore access.",
        _ when endDate < today =>
            $"This school's subscription ended on {endDate:dd MMM yyyy} and has not been renewed. " +
            "Contact your platform administrator.",
        _ => null,
    };
}
