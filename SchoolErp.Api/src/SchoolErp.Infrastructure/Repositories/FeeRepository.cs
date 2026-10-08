using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class FeeRepository : IFeeRepository
{
    private readonly IDbConnectionFactory _factory;
    public FeeRepository(IDbConnectionFactory factory) => _factory = factory;

    /// <summary>
    /// A payment joined to its invoice and student, with the running total paid up to and
    /// including itself. The running total is computed in SQL rather than by summing in memory
    /// so that a single receipt can be fetched without reading the invoice's whole history.
    /// </summary>
    private const string PaymentSelect = @"
        SELECT p.id, p.invoice_id, p.school_id, p.amount, p.method, p.ref, p.paid_date, p.created_at,
               i.invoice_no, i.month, i.amount AS invoice_total, i.student_id, i.student_name, i.class_label,
               s.admission_no,
               (SELECT COALESCE(SUM(e.amount), 0) FROM fee_payment e
                 WHERE e.invoice_id = p.invoice_id AND e.id <= p.id) AS paid_to_date
        FROM fee_payment p
        JOIN fee_invoice i ON i.id = p.invoice_id
        LEFT JOIN students s ON s.id = i.student_id";

    public async Task<IReadOnlyList<FeePaymentRow>> GetPaymentsAsync(long schoolId, long invoiceId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn,
            $"{PaymentSelect} WHERE p.school_id=@sid AND p.invoice_id=@inv ORDER BY p.id",
            MapPayment, ct, ("@sid", schoolId), ("@inv", invoiceId));
    }

    public async Task<FeePaymentRow?> GetPaymentAsync(long schoolId, long paymentId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $"{PaymentSelect} WHERE p.school_id=@sid AND p.id=@id",
            MapPayment, ct, ("@sid", schoolId), ("@id", paymentId));
    }

    private static FeePaymentRow MapPayment(IDataRecord r) => new(
        r.GetLong("id"), r.GetLong("invoice_id"), r.GetLong("school_id"), r.GetDecimal("amount"),
        r.GetStringOrNull("method"), r.GetStringOrNull("ref"), r.GetDateOrNull("paid_date"),
        r.GetDate("created_at"),
        r.GetStringOrNull("invoice_no"), r.GetStringOrNull("month"), r.GetDecimal("invoice_total"),
        r.GetDecimal("paid_to_date"),
        r.GetLong("student_id"), r.GetStringOrNull("student_name"), r.GetStringOrNull("admission_no"),
        r.GetStringOrNull("class_label"));

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

    public async Task<long> RecordPaymentAsync(long schoolId, long invoiceId, decimal amount, string method, string? reference, DateTime date, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var paymentId = await DbHelper.InsertAsync(conn,
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
        if (row is null) return paymentId;

        var newPaid = Math.Min(row.Amount, row.Paid + amount);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE fee_invoice SET paid=@paid, status=@st WHERE id=@id AND school_id=@sid", ct,
            ("@paid", newPaid), ("@st", StatusFor(newPaid, row.Amount, row.DueDate)),
            ("@id", invoiceId), ("@sid", schoolId));
        return paymentId;
    }

    private sealed record InvoiceTotals(decimal Amount, decimal Paid, DateTime? DueDate);

    /// <summary>An invoice that already exists for the student and month being generated.</summary>
    private sealed record ExistingInvoice(long Id, decimal Amount, decimal Paid, DateTime? DueDate);

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

    /// <summary>A head whose amount comes from the student rather than from the class grid.</summary>
    private sealed record PerStudentHead(long FeeTypeId, string Head, string Frequency);

    /// <summary>
    /// The stretch of time a non-monthly head may be charged once in. A null <paramref name="From"/>
    /// means "ever" — a one-time fee is charged once in a student's whole career, not once a year.
    /// </summary>
    private sealed record ChargeWindow(DateTime? From, DateTime? To);

    /// <summary>
    /// Which window a head's frequency gives, anchored on the run's due date so that back-billing
    /// an earlier month asks about that month rather than about today.
    ///
    /// Monthly heads do not come through here: they are charged every run, and the one-invoice-per
    /// -student-per-month rule is what stops those repeating.
    /// </summary>
    private static ChargeWindow WindowFor(string frequency, DateTime due, DateTime? yearStart, DateTime? yearEnd)
    {
        if (frequency == "one_time") return new ChargeWindow(null, null);
        if (yearStart is not { } start || yearEnd is not { } end) return new ChargeWindow(null, null);

        // Quarters and halves are cut from the academic year rather than the calendar, because a
        // school year starting in April has its second quarter in July, not in April.
        var slices = frequency switch { "quarterly" => 4, "half_yearly" => 2, _ => 1 };
        if (slices == 1) return new ChargeWindow(start, end);

        var days = (end - start).TotalDays + 1;
        var each = days / slices;
        var index = Math.Clamp((int)Math.Floor(((due - start).TotalDays) / each), 0, slices - 1);
        var from = start.AddDays(index * each);
        var to = index == slices - 1 ? end : start.AddDays((index + 1) * each).AddDays(-1);
        return new ChargeWindow(from.Date, to.Date);
    }

    public async Task<FeeGenerationResult> GenerateAsync(long schoolId, string month, DateTime due, string className,
        bool includeOneOff, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);

        // Amounts come from the fee structure for the current academic year. They used to come from
        // a Dictionary compiled into this class, which meant every school billed the same five
        // grade names and everything else fell through to a flat 12000.
        // pricing_mode = class only: a distance-priced head keeps its old class rows (migration 022
        // leaves them in place as a record of what the school used to charge), and billing both
        // would put transport on the invoice twice.
        var lines = await DbHelper.QueryAsync(conn, @"
            SELECT c.name AS class_name, ft.id AS fee_type_id, ft.name AS head, fs.frequency, fs.amount
            FROM fee_structures fs
            JOIN classes c ON c.id = fs.class_id
            JOIN fee_types ft ON ft.id = fs.fee_type_id AND ft.is_active = 1 AND ft.pricing_mode = 'class'
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

        // A one-time or yearly head must not be charged twice. Nothing used to stop it: ticking
        // "also bill yearly and one-time charges" on two runs billed admission twice, and a
        // student admitted mid-year could only be caught by re-charging everyone else. So for
        // each such head, read the students who have already had it inside its own window.
        var yearDates = await DbHelper.QueryAsync(conn, @"
            SELECT start_date, end_date FROM academic_years WHERE school_id=@sid AND is_current=1 LIMIT 1",
            r => (start: r.GetDateOrNull("start_date"), end: r.GetDateOrNull("end_date")), ct, ("@sid", schoolId));
        var (yearStart, yearEnd) = yearDates.Count > 0 ? yearDates[0] : (null, null);

        var alreadyCharged = new Dictionary<long, HashSet<long>>();
        if (includeOneOff)
        {
            var repeatable = lines.Select(x => x.line)
                .Where(l => l.Frequency != "monthly")
                .GroupBy(l => l.FeeTypeId)
                .Select(g => g.First());

            foreach (var head in repeatable)
            {
                var window = WindowFor(head.Frequency, due, yearStart, yearEnd);
                var chargedSql = @"SELECT DISTINCT i.student_id
                            FROM fee_invoice i
                            JOIN fee_invoice_line l ON l.invoice_id = i.id
                            WHERE i.school_id=@sid AND l.fee_type_id=@ft";
                var chargedPs = new List<(string, object?)> { ("@sid", schoolId), ("@ft", head.FeeTypeId) };
                // Placed by due date: it is the only real date on an invoice, since the month is
                // free text the admin types.
                if (window.From is { } from) { chargedSql += " AND i.due_date >= @from"; chargedPs.Add(("@from", from)); }
                if (window.To is { } to) { chargedSql += " AND i.due_date <= @to"; chargedPs.Add(("@to", to)); }

                alreadyCharged[head.FeeTypeId] =
                    (await DbHelper.QueryAsync(conn, chargedSql, r => r.GetLong("student_id"), ct, chargedPs.ToArray())).ToHashSet();
            }
        }

        // Transport, and anything else the school prices by distance. Read once for the whole
        // run: the bands are a property of the year, not of the student.
        var perStudentHeads = await DbHelper.QueryAsync(conn, @"
            SELECT id, name, frequency FROM fee_types
            WHERE school_id=@sid AND is_active = 1 AND pricing_mode = 'distance'",
            r => new PerStudentHead(r.GetLong("id"), r.GetString("name"), r.GetString("frequency")),
            ct, ("@sid", schoolId));

        var slabsByHead = new Dictionary<long, List<TransportSlab>>();
        foreach (var h in perStudentHeads)
        {
            slabsByHead[h.FeeTypeId] = await DbHelper.QueryAsync(conn, @"
                SELECT ts.id, ts.school_id, ts.academic_year_id, ts.fee_type_id, ts.up_to_km, ts.amount
                FROM transport_slabs ts
                JOIN academic_years ay ON ay.id = ts.academic_year_id AND ay.is_current = 1
                WHERE ts.school_id=@sid AND ts.fee_type_id=@ft
                ORDER BY ts.up_to_km",
                r => new TransportSlab
                {
                    Id = r.GetLong("id"), SchoolId = r.GetLong("school_id"),
                    AcademicYearId = r.GetLong("academic_year_id"), FeeTypeId = r.GetLong("fee_type_id"),
                    UpToKm = r.GetDecimal("up_to_km"), Amount = r.GetDecimal("amount"),
                }, ct, ("@sid", schoolId), ("@ft", h.FeeTypeId));
        }

        var riders = (await DbHelper.QueryAsync(conn, @"
            SELECT student_id, is_active, distance_km, amount_override
            FROM student_transport WHERE school_id=@sid",
            r => new StudentTransport
            {
                StudentId = r.GetLong("student_id"),
                IsActive = r.GetBool("is_active"),
                DistanceKm = r.GetDecimalOrNull("distance_km"),
                AmountOverride = r.GetDecimalOrNull("amount_override"),
            }, ct, ("@sid", schoolId))).ToDictionary(a => a.StudentId);

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
        var toppedUp = 0;
        var repeatSkipped = 0;
        var unpriced = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        var transportSkipped = new List<string>();

        foreach (var s in students)
        {
            var existing = await DbHelper.QuerySingleAsync(conn, @"
                SELECT id, amount, paid, due_date FROM fee_invoice
                WHERE school_id=@sid AND student_id=@stu AND month=@m LIMIT 1",
                r => new ExistingInvoice(r.GetLong("id"), r.GetDecimal("amount"), r.GetDecimal("paid"),
                                         r.GetDateOrNull("due_date")),
                ct, ("@sid", schoolId), ("@stu", s.id), ("@m", month));

            if (existing is not null)
            {
                // Already invoiced for this month. Rather than skip the student outright, add the
                // non-monthly heads the invoice is missing: a run where the box was left unticked
                // used to be uncorrectable, because re-running it stopped right here. Monthly
                // heads are never topped up — they are already on the invoice, and adding them
                // again would double the month's tuition.
                var topUp = new List<StructureLine>();
                if (includeOneOff && byClass.TryGetValue(s.cls ?? "", out var candidates))
                {
                    var onInvoice = (await DbHelper.QueryAsync(conn,
                        "SELECT fee_type_id FROM fee_invoice_line WHERE invoice_id=@inv AND fee_type_id IS NOT NULL",
                        r => r.GetLong("fee_type_id"), ct, ("@inv", existing.Id))).ToHashSet();

                    foreach (var h in candidates.Where(h => h.Frequency != "monthly"))
                    {
                        if (onInvoice.Contains(h.FeeTypeId)) continue;
                        // The once-only rule still applies: a head charged on another invoice in
                        // this window must not reappear here.
                        if (alreadyCharged.TryGetValue(h.FeeTypeId, out var billed) && billed.Contains(s.id))
                        {
                            repeatSkipped++;
                            continue;
                        }
                        topUp.Add(h);
                    }
                }

                if (topUp.Count == 0) { alreadyBilled++; continue; }

                foreach (var h in topUp)
                    await DbHelper.ExecuteAsync(conn,
                        "INSERT INTO fee_invoice_line (invoice_id, fee_type_id, description, amount) VALUES (@inv, @ft, @d, @amt)", ct,
                        ("@inv", existing.Id), ("@ft", h.FeeTypeId), ("@d", h.Head), ("@amt", h.Amount));

                // The total has to move with the lines, and so does the status: an invoice that
                // was settled in full is no longer settled once a charge is added to it.
                var newAmount = existing.Amount + topUp.Sum(h => h.Amount);
                await DbHelper.ExecuteAsync(conn,
                    "UPDATE fee_invoice SET amount=@amt, status=@st WHERE id=@id AND school_id=@sid", ct,
                    ("@amt", newAmount), ("@st", StatusFor(existing.Paid, newAmount, existing.DueDate)),
                    ("@id", existing.Id), ("@sid", schoolId));

                // Counted apart from a fresh invoice: the admin asked for a correction, and
                // "223 generated" would be a lie about what just happened.
                toppedUp++;
                // The student now holds this head, so a later class in the same run cannot add it.
                foreach (var h in topUp)
                    if (alreadyCharged.TryGetValue(h.FeeTypeId, out var set)) set.Add(s.id);
                continue;
            }

            byClass.TryGetValue(s.cls ?? "", out var allClassHeads);
            allClassHeads ??= new List<StructureLine>();

            // Drop the non-monthly heads this student has already been charged in the current
            // window. This is what makes the checkbox safe to tick twice, and what lets a student
            // admitted in October pick up their admission fee without re-charging the school.
            var classHeads = new List<StructureLine>();
            foreach (var h in allClassHeads)
            {
                if (h.Frequency != "monthly"
                    && alreadyCharged.TryGetValue(h.FeeTypeId, out var billed)
                    && billed.Contains(s.id))
                {
                    repeatSkipped++;
                    continue;
                }
                classHeads.Add(h);
            }

            // Worked out per student: two children in one class can live a street apart and
            // twelve kilometres apart, and a child who walks to school gets no line at all.
            var studentHeads = new List<StructureLine>();
            foreach (var h in perStudentHeads)
            {
                if (!includeOneOff && h.Frequency != "monthly") continue;
                riders.TryGetValue(s.id, out var assignment);
                var fee = TransportPricing.Resolve(assignment, slabsByHead[h.FeeTypeId]);

                if (fee.IsBillable && fee.Amount > 0)
                    studentHeads.Add(new StructureLine(h.FeeTypeId, h.Head, h.Frequency, fee.Amount));
                // Named individually, not counted: the admin has to find these students to fix
                // them, and "3 riders could not be priced" does not say which three.
                else if (fee.Status == TransportFeeStatus.NoDistance || fee.Status == TransportFeeStatus.NoSlabs)
                    transportSkipped.Add($"{s.name} — no distance recorded");
                else if (fee.Status == TransportFeeStatus.BeyondSlabs)
                    transportSkipped.Add($"{s.name} — {assignment?.DistanceKm:0.##} km is past the last band");
            }

            // A class with no prices is still skipped outright, but a rider in an unpriced class
            // is not: their bus is a real charge and belongs on an invoice of its own.
            if (classHeads.Count == 0 && studentHeads.Count == 0)
            {
                unpriced.Add(string.IsNullOrWhiteSpace(s.cls) ? "(no class)" : s.cls!);
                continue;
            }

            var heads = classHeads.Concat(studentHeads).ToList();
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
        return new FeeGenerationResult(created, alreadyBilled, unpriced.ToList(), transportSkipped, repeatSkipped, toppedUp);
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
