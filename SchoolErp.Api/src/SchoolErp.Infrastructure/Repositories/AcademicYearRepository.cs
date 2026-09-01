using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class AcademicYearRepository : IAcademicYearRepository
{
    private readonly IDbConnectionFactory _factory;
    public AcademicYearRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = "id, school_id, name, start_date, end_date, is_current, created_at";

    public async Task<IReadOnlyList<AcademicYear>> GetAllAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM academic_years WHERE school_id=@sid ORDER BY start_date DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@sid", schoolId));
    }

    public async Task<AcademicYear?> GetByIdAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM academic_years WHERE id=@id AND school_id=@sid";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task<bool> NameExistsAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM academic_years WHERE school_id=@sid AND name=@name";
        var ps = new List<(string, object?)> { ("@sid", schoolId), ("@name", name) };
        if (excludeId is { } id) { sql += " AND id<>@id"; ps.Add(("@id", id)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    /// <summary>Two ranges overlap when each starts before the other ends.</summary>
    public async Task<AcademicYear?> FindOverlapAsync(long schoolId, DateTime start, DateTime end,
        long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {Cols} FROM academic_years
                     WHERE school_id=@sid AND start_date <= @end AND end_date >= @start";
        var ps = new List<(string, object?)> { ("@sid", schoolId), ("@start", start.Date), ("@end", end.Date) };
        if (excludeId is { } id) { sql += " AND id<>@id"; ps.Add(("@id", id)); }
        sql += " LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<long> CreateAsync(AcademicYear y, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO academic_years (school_id, name, start_date, end_date, is_current, created_at)
            VALUES (@sid, @name, @start, @end, 0, NOW())";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", y.SchoolId), ("@name", y.Name), ("@start", y.StartDate.Date), ("@end", y.EndDate.Date));
    }

    public async Task UpdateAsync(AcademicYear y, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            UPDATE academic_years SET name=@name, start_date=@start, end_date=@end
            WHERE id=@id AND school_id=@sid";
        await DbHelper.ExecuteAsync(conn, sql, ct,
            ("@name", y.Name), ("@start", y.StartDate.Date), ("@end", y.EndDate.Date),
            ("@id", y.Id), ("@sid", y.SchoolId));
    }

    /// <summary>
    /// Clear-then-set on one connection. Everything keyed by academic year resolves through
    /// is_current, so leaving two years flagged would make that lookup arbitrary.
    /// </summary>
    public async Task SetCurrentAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE academic_years SET is_current=0 WHERE school_id=@sid AND is_current=1", ct, ("@sid", schoolId));
        await DbHelper.ExecuteAsync(conn,
            "UPDATE academic_years SET is_current=1 WHERE id=@id AND school_id=@sid", ct,
            ("@id", id), ("@sid", schoolId));
    }

    public async Task DeleteAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "DELETE FROM academic_years WHERE id=@id AND school_id=@sid", ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task<int> UsageCountAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT (SELECT COUNT(*) FROM class_subjects      WHERE academic_year_id=@id)
                 + (SELECT COUNT(*) FROM teacher_assignments WHERE academic_year_id=@id)";
        return (int)await DbHelper.ScalarLongAsync(conn, sql, ct, ("@id", id));
    }

    private static AcademicYear Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        Name = r.GetString("name"),
        StartDate = r.GetDate("start_date"),
        EndDate = r.GetDate("end_date"),
        IsCurrent = r.GetInt("is_current") == 1,
        CreatedAt = r.GetDate("created_at"),
    };
}
