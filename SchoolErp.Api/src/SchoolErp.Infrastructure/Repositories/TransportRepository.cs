using System.Data;
using System.Globalization;
using System.Text;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class TransportRepository : ITransportRepository
{
    private readonly IDbConnectionFactory _factory;
    public TransportRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string SlabCols = "id, school_id, academic_year_id, fee_type_id, up_to_km, amount";
    private const string AssignCols =
        "id, school_id, student_id, is_active, distance_km, pickup_point, amount_override, note";

    /* ============================ distance bands ============================ */

    public async Task<IReadOnlyList<TransportSlab>> GetSlabsAsync(
        long schoolId, long academicYearId, long feeTypeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            $@"SELECT {SlabCols} FROM transport_slabs
               WHERE school_id=@sid AND academic_year_id=@ay AND fee_type_id=@ft
               ORDER BY up_to_km", MapSlab, ct,
            ("@sid", schoolId), ("@ay", academicYearId), ("@ft", feeTypeId));
    }

    public async Task ReplaceSlabsAsync(long schoolId, long academicYearId, long feeTypeId,
        IReadOnlyList<TransportSlab> slabs, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);

        // Delete and re-insert inside one transaction rather than reconciling row by row. A scale
        // is read as a whole by every caller, so the one state it must never be observed in is
        // half-replaced — an invoice run landing between the delete and the inserts would bill
        // from a set of bands that the school never entered.
        var sql = new StringBuilder();
        var ps = new List<(string, object?)>
        {
            ("@sid", schoolId), ("@ay", academicYearId), ("@ft", feeTypeId),
        };
        sql.AppendLine("START TRANSACTION;");
        sql.AppendLine("DELETE FROM transport_slabs WHERE school_id=@sid AND academic_year_id=@ay AND fee_type_id=@ft;");
        if (slabs.Count > 0)
        {
            sql.AppendLine("INSERT INTO transport_slabs (school_id, academic_year_id, fee_type_id, up_to_km, amount) VALUES");
            for (var i = 0; i < slabs.Count; i++)
            {
                sql.Append(i == 0 ? "  " : ",\n  ").Append(
                    string.Create(CultureInfo.InvariantCulture, $"(@sid, @ay, @ft, @km{i}, @amt{i})"));
                ps.Add(($"@km{i}", slabs[i].UpToKm));
                ps.Add(($"@amt{i}", slabs[i].Amount));
            }
            sql.AppendLine(";");
        }
        sql.AppendLine("COMMIT;");

        await DbHelper.ExecuteAsync(conn, sql.ToString(), ct, ps.ToArray());
    }

    public async Task<int> CopySlabsAsync(long schoolId, long fromAcademicYearId, long toAcademicYearId,
        long feeTypeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // IGNORE plus the uq_slab key means a ceiling the target year already prices keeps its own
        // amount: copying into a year that has been partly set up must not overwrite that work.
        return await DbHelper.ExecuteAsync(conn, @"
            INSERT IGNORE INTO transport_slabs (school_id, academic_year_id, fee_type_id, up_to_km, amount)
            SELECT school_id, @to, fee_type_id, up_to_km, amount
            FROM transport_slabs
            WHERE school_id=@sid AND academic_year_id=@from AND fee_type_id=@ft", ct,
            ("@sid", schoolId), ("@from", fromAcademicYearId), ("@to", toAcademicYearId), ("@ft", feeTypeId));
    }

    /* ============================ who rides ============================ */

    public async Task<IReadOnlyList<StudentTransport>> GetAssignmentsAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            $"SELECT {AssignCols} FROM student_transport WHERE school_id=@sid", MapAssignment, ct,
            ("@sid", schoolId));
    }

    public async Task<StudentTransport?> GetAssignmentAsync(long schoolId, long studentId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $"SELECT {AssignCols} FROM student_transport WHERE school_id=@sid AND student_id=@stu",
            MapAssignment, ct, ("@sid", schoolId), ("@stu", studentId));
    }

    public async Task<bool> SaveAssignmentAsync(StudentTransport a, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // The student id is matched against this school inside the statement, so a crafted id
        // belonging to another tenant selects no row and writes nothing. The affected count is
        // returned rather than swallowed, so the caller can report what it really saved.
        var affected = await DbHelper.ExecuteAsync(conn, @"
            INSERT INTO student_transport
                (school_id, student_id, is_active, distance_km, pickup_point, amount_override, note)
            SELECT s.school_id, s.id, @active, @km, @pickup, @override, @note
            FROM students s
            WHERE s.id=@stu AND s.school_id=@sid AND s.deleted_at IS NULL
            ON DUPLICATE KEY UPDATE
                is_active=VALUES(is_active), distance_km=VALUES(distance_km),
                pickup_point=VALUES(pickup_point), amount_override=VALUES(amount_override),
                note=VALUES(note)", ct,
            ("@active", a.IsActive), ("@km", a.DistanceKm), ("@pickup", a.PickupPoint),
            ("@override", a.AmountOverride), ("@note", a.Note),
            ("@stu", a.StudentId), ("@sid", a.SchoolId));
        // 1 for an insert, 2 for an ON DUPLICATE KEY update, 0 for a student of another school.
        return affected > 0;
    }

    /* ============================ mapping ============================ */

    private static TransportSlab MapSlab(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        AcademicYearId = r.GetLong("academic_year_id"),
        FeeTypeId = r.GetLong("fee_type_id"),
        UpToKm = r.GetDecimal("up_to_km"),
        Amount = r.GetDecimal("amount"),
    };

    private static StudentTransport MapAssignment(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        StudentId = r.GetLong("student_id"),
        IsActive = r.GetBool("is_active"),
        DistanceKm = r.GetDecimalOrNull("distance_km"),
        PickupPoint = r.GetStringOrNull("pickup_point"),
        AmountOverride = r.GetDecimalOrNull("amount_override"),
        Note = r.GetStringOrNull("note"),
    };
}
