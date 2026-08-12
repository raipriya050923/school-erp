using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class FeeRepository : IFeeRepository
{
    private readonly IDbConnectionFactory _factory;
    public FeeRepository(IDbConnectionFactory factory) => _factory = factory;

    private static readonly Dictionary<string, decimal> Rates = new()
    {
        ["Grade 6"] = 10500, ["Grade 7"] = 11500, ["Grade 8"] = 12500, ["Grade 9"] = 13500, ["Grade 10"] = 14500,
    };

    public async Task<IReadOnlyList<FeeInvoiceRow>> GetInvoicesAsync(long schoolId, string? status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = @"SELECT id, school_id, student_id, student_name, class_label, invoice_no, month, amount, paid, due_date, status
                    FROM fee_invoice WHERE school_id=@sid";
        var ps = new List<(string, object?)> { ("@sid", schoolId) };
        if (!string.IsNullOrWhiteSpace(status)) { sql += " AND status=@st"; ps.Add(("@st", status)); }
        sql += " ORDER BY created_at DESC, id DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<FeeInvoiceRow?> GetInvoiceAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"SELECT id, school_id, student_id, student_name, class_label, invoice_no, month, amount, paid, due_date, status
                             FROM fee_invoice WHERE id=@id AND school_id=@sid";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id), ("@sid", schoolId));
    }

    public async Task RecordPaymentAsync(long schoolId, long invoiceId, decimal amount, string method, string? reference, DateTime date, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "INSERT INTO fee_payment (invoice_id, school_id, amount, method, ref, paid_date) VALUES (@id, @sid, @amt, @m, @r, @d)", ct,
            ("@id", invoiceId), ("@sid", schoolId), ("@amt", amount), ("@m", method), ("@r", reference), ("@d", date.Date));
        // recompute paid + status
        await DbHelper.ExecuteAsync(conn, @"
            UPDATE fee_invoice SET
              paid = LEAST(amount, paid + @amt),
              status = CASE WHEN paid + @amt >= amount THEN 'paid' WHEN paid + @amt > 0 THEN 'partial' ELSE status END
            WHERE id=@id AND school_id=@sid", ct,
            ("@amt", amount), ("@id", invoiceId), ("@sid", schoolId));
    }

    public async Task<int> GenerateAsync(long schoolId, string month, DateTime due, string className, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = @"SELECT id, class_name, section_name, CONCAT(first_name,' ',last_name) AS name
                    FROM students WHERE school_id=@sid AND status='active' AND deleted_at IS NULL";
        var ps = new List<(string, object?)> { ("@sid", schoolId) };
        if (className != "All") { sql += " AND class_name=@cls"; ps.Add(("@cls", className)); }
        sql += " LIMIT 2000";
        var students = await DbHelper.QueryAsync(conn, sql, r => (
            id: r.GetLong("id"),
            cls: r.GetStringOrNull("class_name"),
            sec: r.GetStringOrNull("section_name"),
            name: r.GetString("name")), ct, ps.ToArray());

        var created = 0;
        var seq = 900;
        foreach (var s in students)
        {
            var exists = await DbHelper.ScalarLongAsync(conn,
                "SELECT COUNT(*) FROM fee_invoice WHERE school_id=@sid AND student_id=@stu AND month=@m", ct,
                ("@sid", schoolId), ("@stu", s.id), ("@m", month));
            if (exists > 0) continue;
            var amount = Rates.TryGetValue(s.cls ?? "", out var r) ? r : 12000m;
            await DbHelper.ExecuteAsync(conn, @"
                INSERT INTO fee_invoice (school_id, student_id, student_name, class_label, invoice_no, month, amount, paid, due_date, status)
                VALUES (@sid, @stu, @name, @cls, @no, @m, @amt, 0, @due, 'unpaid')", ct,
                ("@sid", schoolId), ("@stu", s.id), ("@name", s.name),
                ("@cls", $"{s.cls}-{s.sec}"), ("@no", $"FI-26-{++seq:D4}"), ("@m", month),
                ("@amt", amount), ("@due", due.Date));
            created++;
        }
        return created;
    }

    private static FeeInvoiceRow Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"), SchoolId = r.GetLong("school_id"), StudentId = r.GetLong("student_id"),
        StudentName = r.GetStringOrNull("student_name"), ClassLabel = r.GetStringOrNull("class_label"),
        InvoiceNo = r.GetStringOrNull("invoice_no"), Month = r.GetStringOrNull("month"),
        Amount = r.GetDecimal("amount"), Paid = r.GetDecimal("paid"), DueDate = r.GetDateOrNull("due_date"),
        Status = r.GetString("status"),
    };
}
