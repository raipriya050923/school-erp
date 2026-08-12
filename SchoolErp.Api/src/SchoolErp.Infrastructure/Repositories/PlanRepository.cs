using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class PlanRepository : IPlanRepository
{
    private readonly IDbConnectionFactory _factory;
    public PlanRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = @"
        id, name, slug, description, price_monthly, price_yearly,
        max_students, max_staff, max_storage_mb, trial_days, is_active, sort_order,
        created_at, updated_at";

    public async Task<IReadOnlyList<SubscriptionPlan>> GetAllAsync(CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM subscription_plans ORDER BY sort_order, price_monthly";
        return await DbHelper.QueryAsync(conn, sql, Map, ct);
    }

    public async Task<SubscriptionPlan?> GetByIdAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM subscription_plans WHERE id=@id";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id));
    }

    public async Task<long> CreateAsync(SubscriptionPlan p, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO subscription_plans
              (name, slug, description, price_monthly, price_yearly, max_students, max_staff,
               trial_days, is_active, created_at, updated_at)
            VALUES
              (@name, @slug, @desc, @pm, @py, @maxStu, @maxStaff, @trial, @active, NOW(), NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@name", p.Name), ("@slug", p.Slug), ("@desc", p.Description),
            ("@pm", p.PriceMonthly), ("@py", p.PriceYearly),
            ("@maxStu", (object?)p.MaxStudents), ("@maxStaff", (object?)p.MaxStaff),
            ("@trial", p.TrialDays), ("@active", p.IsActive));
    }

    public async Task UpdateAsync(SubscriptionPlan p, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            UPDATE subscription_plans SET
              description=@desc, price_monthly=@pm, price_yearly=@py,
              max_students=@maxStu, max_staff=@maxStaff, trial_days=@trial, updated_at=NOW()
            WHERE id=@id;";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@desc", p.Description), ("@pm", p.PriceMonthly), ("@py", p.PriceYearly),
            ("@maxStu", (object?)p.MaxStudents), ("@maxStaff", (object?)p.MaxStaff),
            ("@trial", p.TrialDays), ("@id", p.Id));
    }

    public async Task SetActiveAsync(long id, bool isActive, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE subscription_plans SET is_active=@a, updated_at=NOW() WHERE id=@id", ct,
            ("@a", isActive), ("@id", id));
    }

    public async Task<bool> ExistsByNameAsync(string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM subscription_plans WHERE name=@name";
        var ps = new List<(string, object?)> { ("@name", name) };
        if (excludeId.HasValue) { sql += " AND id <> @id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    public async Task<int> GetSubscriberCountAsync(long planId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM school_subscriptions WHERE plan_id=@id AND status IN ('trial','active','past_due')",
            ct, ("@id", planId));
    }

    private static SubscriptionPlan Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        Name = r.GetString("name"),
        Slug = r.GetString("slug"),
        Description = r.GetStringOrNull("description"),
        PriceMonthly = r.GetDecimal("price_monthly"),
        PriceYearly = r.GetDecimal("price_yearly"),
        MaxStudents = r.GetIntOrNull("max_students"),
        MaxStaff = r.GetIntOrNull("max_staff"),
        MaxStorageMb = r.GetIntOrNull("max_storage_mb"),
        TrialDays = r.GetInt("trial_days"),
        IsActive = r.GetBool("is_active"),
        SortOrder = r.GetInt("sort_order"),
        CreatedAt = r.GetDate("created_at"),
        UpdatedAt = r.GetDate("updated_at"),
    };
}
