using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class SubscriptionRepository : ISubscriptionRepository
{
    private readonly IDbConnectionFactory _factory;
    public SubscriptionRepository(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>Every read returns the same shape, so <see cref="Map"/> works for all of them.</summary>
    private const string SelectJoined = @"
        SELECT ss.id, ss.school_id, ss.plan_id, ss.billing_cycle, ss.start_date, ss.end_date,
               ss.price, ss.status, ss.auto_renew, ss.cancelled_at, ss.created_at, ss.updated_at,
               s.name AS school_name, p.name AS plan_name
        FROM school_subscriptions ss
        JOIN schools s ON s.id = ss.school_id
        JOIN subscription_plans p ON p.id = ss.plan_id";

    public async Task<IReadOnlyList<SchoolSubscription>> GetAllAsync(string? status, long? planId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"{SelectJoined} WHERE 1=1";
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

    public async Task<long> CreateAsync(SchoolSubscription s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO school_subscriptions
              (school_id, plan_id, billing_cycle, start_date, end_date, price, status, auto_renew,
               created_at, updated_at)
            VALUES
              (@sid, @pid, @cycle, @start, @end, @price, @status, @renew, NOW(), NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", s.SchoolId), ("@pid", s.PlanId), ("@cycle", s.BillingCycle),
            ("@start", s.StartDate), ("@end", s.EndDate), ("@price", s.Price),
            ("@status", s.Status), ("@renew", s.AutoRenew));
    }

    public async Task<SchoolSubscription?> GetCurrentBySchoolAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"{SelectJoined}
            WHERE ss.school_id=@sid AND ss.status IN ('trial','active','past_due')
            ORDER BY ss.created_at DESC LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@sid", schoolId));
    }

    public async Task<SchoolSubscription?> GetLatestBySchoolAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"{SelectJoined} WHERE ss.school_id=@sid ORDER BY ss.created_at DESC LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@sid", schoolId));
    }

    public async Task<SchoolSubscription?> GetByIdAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"{SelectJoined} WHERE ss.id=@id LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id));
    }

    public async Task ActivateAsync(long id, DateTime startDate, DateTime endDate, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"UPDATE school_subscriptions
              SET status='active', start_date=@start, end_date=@end, cancelled_at=NULL, updated_at=NOW()
              WHERE id=@id", ct,
            ("@start", startDate), ("@end", endDate), ("@id", id));
    }

    public async Task UpdatePlanAsync(long id, long planId, string billingCycle, decimal price, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"UPDATE school_subscriptions
              SET plan_id=@pid, billing_cycle=@cycle, price=@price, updated_at=NOW()
              WHERE id=@id", ct,
            ("@pid", planId), ("@cycle", billingCycle), ("@price", price), ("@id", id));
    }

    public async Task<IReadOnlyDictionary<long, string>> GetCurrentPlanNamesAsync(CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // A school can accumulate past subscriptions, so take the newest live one per school.
        const string sql = @"
            SELECT ss.school_id, p.name AS plan_name
            FROM school_subscriptions ss
            JOIN subscription_plans p ON p.id = ss.plan_id
            WHERE ss.status IN ('trial','active','past_due')
            ORDER BY ss.school_id, ss.created_at DESC";
        var rows = await DbHelper.QueryAsync(conn, sql,
            r => (SchoolId: r.GetLong("school_id"), PlanName: r.GetString("plan_name")), ct);

        var map = new Dictionary<long, string>();
        foreach (var (schoolId, planName) in rows)
            map.TryAdd(schoolId, planName);   // first row per school is the newest
        return map;
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
