using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class SchoolRepository : ISchoolRepository
{
    private readonly IDbConnectionFactory _factory;
    public SchoolRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string BaseColumns = @"
        id, school_code, name, subdomain, custom_domain, logo_url, email, phone,
        city, state, country, postal_code, timezone, currency, affiliation_board,
        status, onboarded_at, created_at, updated_at";

    public async Task<IReadOnlyList<School>> GetAllAsync(string? search, string? status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {BaseColumns} FROM schools WHERE deleted_at IS NULL";
        var ps = new List<(string, object?)>();
        if (!string.IsNullOrWhiteSpace(search))
        {
            sql += " AND (name LIKE @s OR school_code LIKE @s OR city LIKE @s)";
            ps.Add(("@s", $"%{search}%"));
        }
        if (!string.IsNullOrWhiteSpace(status))
        {
            sql += " AND status = @status";
            ps.Add(("@status", status));
        }
        sql += " ORDER BY created_at DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<School?> GetByIdAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {BaseColumns} FROM schools WHERE id = @id AND deleted_at IS NULL";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id));
    }

    public async Task<long> CreateAsync(School s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO schools
              (school_code, name, subdomain, email, phone, city, state, country,
               postal_code, affiliation_board, status, onboarded_at, created_at, updated_at)
            VALUES
              (@code, @name, @subdomain, @email, @phone, @city, @state, @country,
               @postal, @board, @status, @onboarded, NOW(), NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@code", s.SchoolCode), ("@name", s.Name), ("@subdomain", s.Subdomain),
            ("@email", s.Email), ("@phone", s.Phone), ("@city", s.City), ("@state", s.State),
            ("@country", s.Country), ("@postal", s.PostalCode), ("@board", s.AffiliationBoard),
            ("@status", s.Status), ("@onboarded", (object?)s.OnboardedAt));
    }

    public async Task UpdateAsync(School s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            UPDATE schools SET
              name=@name, email=@email, phone=@phone, city=@city, state=@state,
              country=@country, postal_code=@postal, affiliation_board=@board,
              status=@status, updated_at=NOW()
            WHERE id=@id AND deleted_at IS NULL;";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@name", s.Name), ("@email", s.Email), ("@phone", s.Phone), ("@city", s.City),
            ("@state", s.State), ("@country", s.Country), ("@postal", s.PostalCode),
            ("@board", s.AffiliationBoard), ("@status", s.Status), ("@id", s.Id));
    }

    public async Task UpdateStatusAsync(long id, string status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"UPDATE schools SET status=@status, updated_at=NOW() WHERE id=@id;";
        await DbHelper.ExecuteAsync(conn, sql, ct, ("@status", status), ("@id", id));
    }

    public async Task<bool> ExistsByNameAsync(string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM schools WHERE name=@name AND deleted_at IS NULL";
        var ps = new List<(string, object?)> { ("@name", name) };
        if (excludeId.HasValue) { sql += " AND id <> @id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    public async Task<int> CountAsync(CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM schools WHERE deleted_at IS NULL", ct);
    }

    public async Task<int> GetStudentCountAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM students WHERE school_id=@id AND deleted_at IS NULL", ct,
            ("@id", schoolId));
    }

    private static School Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolCode = r.GetString("school_code"),
        Name = r.GetString("name"),
        Subdomain = r.GetString("subdomain"),
        CustomDomain = r.GetStringOrNull("custom_domain"),
        LogoUrl = r.GetStringOrNull("logo_url"),
        Email = r.GetString("email"),
        Phone = r.GetString("phone"),
        City = r.GetStringOrNull("city"),
        State = r.GetStringOrNull("state"),
        Country = r.GetStringOrNull("country"),
        PostalCode = r.GetStringOrNull("postal_code"),
        Timezone = r.GetString("timezone"),
        Currency = r.GetString("currency"),
        AffiliationBoard = r.GetStringOrNull("affiliation_board"),
        Status = r.GetString("status"),
        OnboardedAt = r.GetDateOrNull("onboarded_at"),
        CreatedAt = r.GetDate("created_at"),
        UpdatedAt = r.GetDate("updated_at"),
    };
}
