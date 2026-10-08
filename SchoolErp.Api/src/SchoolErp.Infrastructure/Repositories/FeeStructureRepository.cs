using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class FeeStructureRepository : IFeeStructureRepository
{
    private readonly IDbConnectionFactory _factory;
    public FeeStructureRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string HeadCols = "id, school_id, name, description, frequency, pricing_mode, is_refundable, is_active";

    /// <summary>The set every new school starts with; mirrors migration 013.</summary>
    private static readonly (string Name, string Description, string Frequency, string PricingMode)[] DefaultHeads =
    {
        ("Tuition Fee", "Core monthly teaching fee", "monthly", "class"),
        // Priced from the rider's distance, not from their class — see migration 022.
        ("Transport Fee", "Bus service, billed by distance", "monthly", "distance"),
        ("Exam Fee", "Charged once per academic year", "yearly", "class"),
        ("Library Fee", "Charged once per academic year", "yearly", "class"),
        ("Admission Fee", "Charged once, on admission", "one_time", "class"),
    };

    /* ============================ heads ============================ */

    public async Task<IReadOnlyList<FeeHead>> GetHeadsAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            $"SELECT {HeadCols} FROM fee_types WHERE school_id=@sid ORDER BY is_active DESC, name",
            MapHead, ct, ("@sid", schoolId));
    }

    public async Task<FeeHead?> GetHeadAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $"SELECT {HeadCols} FROM fee_types WHERE id=@id AND school_id=@sid", MapHead, ct,
            ("@id", id), ("@sid", schoolId));
    }

    public async Task<bool> HeadNameExistsAsync(long schoolId, string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM fee_types WHERE school_id=@sid AND name=@name";
        var ps = new List<(string, object?)> { ("@sid", schoolId), ("@name", name) };
        if (excludeId.HasValue) { sql += " AND id<>@id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    public async Task<long> CreateHeadAsync(FeeHead h, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn,
            @"INSERT INTO fee_types (school_id, name, description, frequency, pricing_mode, is_refundable, is_active)
              VALUES (@sid, @name, @descr, @freq, @mode, @ref, @active)", ct,
            ("@sid", h.SchoolId), ("@name", h.Name), ("@descr", h.Description),
            ("@freq", h.Frequency), ("@mode", h.PricingMode), ("@ref", h.IsRefundable), ("@active", h.IsActive));
    }

    public async Task UpdateHeadAsync(FeeHead h, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"UPDATE fee_types SET name=@name, description=@descr, frequency=@freq,
                     pricing_mode=@mode, is_refundable=@ref
              WHERE id=@id AND school_id=@sid", ct,
            ("@name", h.Name), ("@descr", h.Description), ("@freq", h.Frequency),
            ("@mode", h.PricingMode), ("@ref", h.IsRefundable),
            ("@id", h.Id), ("@sid", h.SchoolId));

        // Cells carry a copy of the frequency so the invoice run reads one table; keep them in step.
        await DbHelper.ExecuteAsync(conn,
            "UPDATE fee_structures SET frequency=@freq WHERE school_id=@sid AND fee_type_id=@id", ct,
            ("@freq", h.Frequency), ("@sid", h.SchoolId), ("@id", h.Id));
    }

    public async Task SetHeadActiveAsync(long schoolId, long id, bool isActive, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE fee_types SET is_active=@a WHERE id=@id AND school_id=@sid", ct,
            ("@a", isActive), ("@id", id), ("@sid", schoolId));
    }

    public async Task SeedDefaultHeadsAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        foreach (var (name, descr, freq, mode) in DefaultHeads)
        {
            // uq_ft (school_id, name) makes this idempotent.
            await DbHelper.ExecuteAsync(conn,
                @"INSERT IGNORE INTO fee_types (school_id, name, description, frequency, pricing_mode, is_refundable, is_active)
                  VALUES (@sid, @name, @descr, @freq, @mode, 0, 1)", ct,
                ("@sid", schoolId), ("@name", name), ("@descr", descr), ("@freq", freq), ("@mode", mode));
        }
    }

    /* ============================ cells ============================ */

    public async Task<IReadOnlyList<FeeStructureCell>> GetCellsAsync(long schoolId, long academicYearId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn, @"
            SELECT fs.id, fs.school_id, fs.academic_year_id, fs.class_id, c.name AS class_name,
                   fs.fee_type_id, ft.name AS head_name, ft.frequency, fs.amount
            FROM fee_structures fs
            JOIN classes c ON c.id = fs.class_id
            JOIN fee_types ft ON ft.id = fs.fee_type_id
            WHERE fs.school_id=@sid AND fs.academic_year_id=@ay
            ORDER BY c.id, ft.name", MapCell, ct,
            ("@sid", schoolId), ("@ay", academicYearId));
    }

    public async Task SaveCellAsync(long schoolId, long academicYearId, long classId, long feeTypeId, decimal amount, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        if (amount <= 0)
        {
            await DbHelper.ExecuteAsync(conn,
                @"DELETE FROM fee_structures
                  WHERE school_id=@sid AND academic_year_id=@ay AND class_id=@cls AND fee_type_id=@ft", ct,
                ("@sid", schoolId), ("@ay", academicYearId), ("@cls", classId), ("@ft", feeTypeId));
            return;
        }

        // uq_fs (academic_year_id, class_id, fee_type_id) turns this into an update on re-save.
        // Selecting from fee_types rather than passing the frequency in keeps the copy honest and
        // rejects a fee_type_id belonging to another school.
        await DbHelper.ExecuteAsync(conn, @"
            INSERT INTO fee_structures
                (school_id, academic_year_id, class_id, fee_type_id, amount, frequency, due_day, late_fine_amount)
            SELECT @sid, @ay, @cls, ft.id, @amt, ft.frequency, NULL, 0
            FROM fee_types ft
            WHERE ft.id=@ft AND ft.school_id=@sid
            ON DUPLICATE KEY UPDATE amount = VALUES(amount), frequency = VALUES(frequency)", ct,
            ("@sid", schoolId), ("@ay", academicYearId), ("@cls", classId), ("@ft", feeTypeId), ("@amt", amount));
    }

    public async Task<int> CopyYearAsync(long schoolId, long fromAcademicYearId, long toAcademicYearId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // IGNORE rather than ON DUPLICATE KEY UPDATE: copying must not overwrite a price the school
        // has already set for the target year.
        return await DbHelper.ExecuteAsync(conn, @"
            INSERT IGNORE INTO fee_structures
                (school_id, academic_year_id, class_id, fee_type_id, amount, frequency, due_day, late_fine_amount)
            SELECT fs.school_id, @to, fs.class_id, fs.fee_type_id, fs.amount, fs.frequency, fs.due_day, fs.late_fine_amount
            FROM fee_structures fs
            WHERE fs.school_id=@sid AND fs.academic_year_id=@from", ct,
            ("@sid", schoolId), ("@from", fromAcademicYearId), ("@to", toAcademicYearId));
    }

    private static FeeHead MapHead(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        Name = r.GetString("name"),
        Description = r.GetStringOrNull("description"),
        Frequency = r.GetString("frequency"),
        PricingMode = r.GetString("pricing_mode"),
        IsRefundable = r.GetBool("is_refundable"),
        IsActive = r.GetBool("is_active"),
    };

    private static FeeStructureCell MapCell(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        AcademicYearId = r.GetLong("academic_year_id"),
        ClassId = r.GetLong("class_id"),
        ClassName = r.GetString("class_name"),
        FeeTypeId = r.GetLong("fee_type_id"),
        HeadName = r.GetString("head_name"),
        Frequency = r.GetString("frequency"),
        Amount = r.GetDecimal("amount"),
    };
}
