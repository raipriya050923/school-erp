using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class SubjectRepository : ISubjectRepository
{
    private readonly IDbConnectionFactory _factory;
    public SubjectRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = "id, school_id, name, code, subject_type, is_active";

    /// <summary>The set every new school starts with; mirrors migration 008.</summary>
    private static readonly (string Name, string Code)[] Defaults =
    {
        ("English", "ENG"),
        ("Mathematics", "MAT"),
        ("Science", "SCI"),
        ("Social Studies", "SOC"),
        ("Computer Science", "CSC"),
    };

    public async Task<IReadOnlyList<Subject>> GetAllAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            $"SELECT {Cols} FROM subjects WHERE school_id=@sid ORDER BY name", Map, ct, ("@sid", schoolId));
    }

    public async Task<IReadOnlyList<string>> GetNamesAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            "SELECT name FROM subjects WHERE school_id=@sid AND is_active=1 ORDER BY name",
            r => r.GetString("name"), ct, ("@sid", schoolId));
    }

    public async Task<Subject?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $"SELECT {Cols} FROM subjects WHERE id=@id AND school_id=@sid", Map, ct,
            ("@id", id), ("@sid", schoolId));
    }

    public async Task<bool> ExistsByNameAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM subjects WHERE school_id=@sid AND name=@name";
        var ps = new List<(string, object?)> { ("@sid", schoolId), ("@name", name) };
        if (excludeId.HasValue) { sql += " AND id<>@id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    public async Task<long> CreateAsync(Subject s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn,
            @"INSERT INTO subjects (school_id, name, code, subject_type, is_active)
              VALUES (@sid, @name, @code, @type, @active)", ct,
            ("@sid", s.SchoolId), ("@name", s.Name), ("@code", s.Code),
            ("@type", s.SubjectType), ("@active", s.IsActive));
    }

    public async Task UpdateAsync(Subject s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"UPDATE subjects SET name=@name, code=@code, subject_type=@type
              WHERE id=@id AND school_id=@sid", ct,
            ("@name", s.Name), ("@code", s.Code), ("@type", s.SubjectType),
            ("@id", s.Id), ("@sid", s.SchoolId));
    }

    public async Task SetActiveAsync(long schoolId, long id, bool isActive, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE subjects SET is_active=@a WHERE id=@id AND school_id=@sid", ct,
            ("@a", isActive), ("@id", id), ("@sid", schoolId));
    }

    public async Task SeedDefaultsAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        foreach (var (name, code) in Defaults)
        {
            // uq_subject (school_id, name) makes this idempotent.
            await DbHelper.ExecuteAsync(conn,
                @"INSERT IGNORE INTO subjects (school_id, name, code, subject_type, is_active)
                  VALUES (@sid, @name, @code, 'theory', 1)", ct,
                ("@sid", schoolId), ("@name", name), ("@code", code));
        }
    }

    private static Subject Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        Name = r.GetString("name"),
        Code = r.GetStringOrNull("code"),
        SubjectType = r.GetString("subject_type"),
        IsActive = r.GetBool("is_active"),
    };
}
