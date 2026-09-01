using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class FeeRepository : IFeeRepository
{
    private readonly IDbConnectionFactory _factory;
    public FeeRepository(IDbConnectionFactory factory) => _factory = factory;

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

    public async Task<IReadOnlyList<FeeInvoiceLine>> GetInvoiceLinesAsync(long schoolId, long invoiceId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Joined back to fee_invoice so a line cannot be read across tenants by guessing an id.
        return await DbHelper.QueryAsync(conn, @"
            SELECT l.id, l.invoice_id, l.fee_type_id, l.description, l.amount
            FROM fee_invoice_line l
            JOIN fee_invoice i ON i.id = l.invoice_id
            WHERE l.invoice_id=@id AND i.school_id=@sid
            ORDER BY l.id",
            r => new FeeInvoiceLine
            {
                Id = r.GetLong("id"),
                InvoiceId = r.GetLong("invoice_id"),
                FeeTypeId = r.GetLongOrNull("fee_type_id"),
                Description = r.GetString("description"),
                Amount = r.GetDecimal("amount"),
            }, ct, ("@id", invoiceId), ("@sid", schoolId));
    }

    public async Task RecordPaymentAsync(long schoolId, long invoiceId, decimal amount, string method, string? reference, DateTime date, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "INSERT INTO fee_payment (invoice_id, school_id, amount, method, ref, paid_date) VALUES (@id, @sid, @amt, @m, @r, @d)", ct,
            ("@id", invoiceId), ("@sid", schoolId), ("@amt", amount), ("@m", method), ("@r", reference), ("@d", date.Date));

        // The new total and status are worked out here rather than inside the UPDATE. Deriving both
        // in SQL counted the payment twice: MySQL applies SET clauses left to right, so a CASE that
        // read `paid` after `paid` had been assigned saw the already-incremented value, and any
        // payment of half the balance or more settled the whole invoice.
        var row = await DbHelper.QuerySingleAsync(conn,
            "SELECT amount, paid, due_date FROM fee_invoice WHERE id=@id AND school_id=@sid",
            r => new InvoiceTotals(r.GetDecimal("amount"), r.GetDecimal("paid"), r.GetDateOrNull("due_date")),
            ct, ("@id", invoiceId), ("@sid", schoolId));
        if (row is null) return;

        var newPaid = Math.Min(row.Amount, row.Paid + amount);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE fee_invoice SET paid=@paid, status=@st WHERE id=@id AND school_id=@sid", ct,
            ("@paid", newPaid), ("@st", StatusFor(newPaid, row.Amount, row.DueDate)),
            ("@id", invoiceId), ("@sid", schoolId));
    }

    private sealed record InvoiceTotals(decimal Amount, decimal Paid, DateTime? DueDate);

    /// <summary>Settled invoices are 'paid'; anything still owing past its due date is 'overdue'.</summary>
    private static string StatusFor(decimal paid, decimal amount, DateTime? dueDate)
    {
        if (paid >= amount) return "paid";
        if (dueDate is { } due && due.Date < DateTime.UtcNow.Date) return "overdue";
        return paid > 0 ? "partial" : "unpaid";
    }

    public async Task<int> MarkOverdueAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ExecuteAsync(conn, @"
            UPDATE fee_invoice
            SET status='overdue'
            WHERE school_id=@sid AND status IN ('unpaid','partial')
              AND due_date IS NOT NULL AND due_date < CURDATE()", ct,
            ("@sid", schoolId));
    }

    /// <summary>One priced head, ready to become an invoice line.</summary>
    private sealed record StructureLine(long FeeTypeId, string Head, string Frequency, decimal Amount);

    public async Task<FeeGenerationResult> GenerateAsync(long schoolId, string month, DateTime due, string className,
        bool includeOneOff, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);

        // Amounts come from the fee structure for the current academic year. They used to come from
        // a Dictionary compiled into this class, which meant every school billed the same five
        // grade names and everything else fell through to a flat 12000.
        var lines = await DbHelper.QueryAsync(conn, @"
            SELECT c.name AS class_name, ft.id AS fee_type_id, ft.name AS head, fs.frequency, fs.amount
            FROM fee_structures fs
            JOIN classes c ON c.id = fs.class_id
            JOIN fee_types ft ON ft.id = fs.fee_type_id AND ft.is_active = 1
            JOIN academic_years ay ON ay.id = fs.academic_year_id AND ay.is_current = 1
            WHERE fs.school_id=@sid AND fs.amount > 0",
            r => (cls: r.GetString("class_name"),
                  line: new StructureLine(r.GetLong("fee_type_id"), r.GetString("head"),
                                          r.GetString("frequency"), r.GetDecimal("amount"))),
            ct, ("@sid", schoolId));

        // A monthly run bills the monthly heads. Yearly and one-time charges are only added when
        // the admin asks for them, which is normally the first run of the academic year.
        var byClass = lines
            .Where(x => includeOneOff || x.line.Frequency == "monthly")
            .GroupBy(x => x.cls)
            .ToDictionary(g => g.Key, g => g.Select(x => x.line).ToList(), StringComparer.OrdinalIgnoreCase);

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

        // Continue from the highest number this school has already used. Restarting from a constant
        // meant every generation run re-issued FI-26-0901 onwards, and nothing stops duplicates:
        // fee_invoice has no unique key on invoice_no.
        var seq = await DbHelper.ScalarLongAsync(conn, @"
            SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(invoice_no, '-', -1) AS UNSIGNED)), 900)
            FROM fee_invoice
            WHERE school_id=@sid AND invoice_no LIKE 'FI-%'", ct, ("@sid", schoolId));
        var year = DateTime.UtcNow.ToString("yy");

        var created = 0;
        var alreadyBilled = 0;
        var unpriced = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var s in students)
        {
            var exists = await DbHelper.ScalarLongAsync(conn,
                "SELECT COUNT(*) FROM fee_invoice WHERE school_id=@sid AND student_id=@stu AND month=@m", ct,
                ("@sid", schoolId), ("@stu", s.id), ("@m", month));
            if (exists > 0) { alreadyBilled++; continue; }

            if (!byClass.TryGetValue(s.cls ?? "", out var heads) || heads.Count == 0)
            {
                unpriced.Add(string.IsNullOrWhiteSpace(s.cls) ? "(no class)" : s.cls!);
                continue;
            }

            var amount = heads.Sum(h => h.Amount);
            var invoiceId = await DbHelper.InsertAsync(conn, @"
                INSERT INTO fee_invoice (school_id, student_id, student_name, class_label, invoice_no, month, amount, paid, due_date, status)
                VALUES (@sid, @stu, @name, @cls, @no, @m, @amt, 0, @due, 'unpaid')", ct,
                ("@sid", schoolId), ("@stu", s.id), ("@name", s.name),
                ("@cls", $"{s.cls}-{s.sec}"), ("@no", $"FI-{year}-{++seq:D4}"), ("@m", month),
                ("@amt", amount), ("@due", due.Date));

            // Lines are written even for a single head: without them the total is an opaque number
            // that nobody can explain once the structure has moved on.
            foreach (var h in heads)
                await DbHelper.ExecuteAsync(conn,
                    "INSERT INTO fee_invoice_line (invoice_id, fee_type_id, description, amount) VALUES (@inv, @ft, @d, @amt)", ct,
                    ("@inv", invoiceId), ("@ft", h.FeeTypeId), ("@d", h.Head), ("@amt", h.Amount));

            created++;
        }
        return new FeeGenerationResult(created, alreadyBilled, unpriced.ToList());
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
