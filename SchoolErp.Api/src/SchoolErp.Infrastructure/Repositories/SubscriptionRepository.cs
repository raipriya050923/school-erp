using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class SubscriptionRepository : ISubscriptionRepository
{
    private readonly IDbConnectionFactory _factory;
    public SubscriptionRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<SchoolSubscription>> GetAllAsync(string? status, long? planId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = @"
            SELECT ss.id, ss.school_id, ss.plan_id, ss.billing_cycle, ss.start_date, ss.end_date,
                   ss.price, ss.status, ss.auto_renew, ss.cancelled_at, ss.created_at, ss.updated_at,
                   s.name AS school_name, p.name AS plan_name
            FROM school_subscriptions ss
            JOIN schools s ON s.id = ss.school_id
            JOIN subscription_plans p ON p.id = ss.plan_id
            WHERE 1=1";
        var ps = new List<(string, object?)>();
        if (!string.IsNullOrWhiteSpace(status)) { sql += " AND ss.status=@st"; ps.Add(("@st", status)); }
        if (planId.HasValue) { sql += " AND ss.plan_id=@pid"; ps.Add(("@pid", planId.Value)); }
        sql += " ORDER BY ss.created_at DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<int> CountByStatusAsync(string status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM school_subscriptions WHERE status=@st", ct, ("@st", status));
    }

    public async Task<decimal> GetMonthlyRecurringRevenueAsync(CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // normalise yearly plans to a monthly figure
        const string sql = @"
            SELECT COALESCE(SUM(CASE WHEN billing_cycle='yearly' THEN price/12 ELSE price END), 0)
            FROM school_subscriptions WHERE status='active';";
        return await DbHelper.ScalarDecimalAsync(conn, sql, ct);
    }

    private static SchoolSubscription Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        PlanId = r.GetLong("plan_id"),
        BillingCycle = r.GetString("billing_cycle"),
        StartDate = r.GetDate("start_date"),
        EndDate = r.GetDate("end_date"),
        Price = r.GetDecimal("price"),
        Status = r.GetString("status"),
        AutoRenew = r.GetBool("auto_renew"),
        CancelledAt = r.GetDateOrNull("cancelled_at"),
        CreatedAt = r.GetDate("created_at"),
        UpdatedAt = r.GetDate("updated_at"),
        SchoolName = r.GetStringOrNull("school_name"),
        PlanName = r.GetStringOrNull("plan_name"),
    };
}
