using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class BillingRepository : IBillingRepository
{
    private readonly IDbConnectionFactory _factory;
    public BillingRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IReadOnlyList<PlatformInvoice>> GetInvoicesAsync(string? status, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = @"
            SELECT pi.id, pi.school_id, pi.subscription_id, pi.invoice_no, pi.amount, pi.tax_amount,
                   pi.total_amount, pi.due_date, pi.status, pi.issued_at, pi.paid_at, pi.reminded_at,
                   pi.created_at, s.name AS school_name
            FROM platform_invoices pi
            JOIN schools s ON s.id = pi.school_id
            WHERE 1=1";
        var ps = new List<(string, object?)>();
        if (!string.IsNullOrWhiteSpace(status)) { sql += " AND pi.status=@st"; ps.Add(("@st", status)); }
        sql += " ORDER BY pi.created_at DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ps.ToArray());
    }

    public async Task<PlatformInvoice?> GetInvoiceByIdAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT pi.id, pi.school_id, pi.subscription_id, pi.invoice_no, pi.amount, pi.tax_amount,
                   pi.total_amount, pi.due_date, pi.status, pi.issued_at, pi.paid_at, pi.reminded_at,
                   pi.created_at, s.name AS school_name
            FROM platform_invoices pi
            JOIN schools s ON s.id = pi.school_id
            WHERE pi.id=@id;";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@id", id));
    }

    public async Task<long> AddPaymentAsync(PlatformPayment p, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO platform_payments
              (invoice_id, school_id, amount, method, transaction_ref, status, paid_at, remarks, created_at)
            VALUES
              (@inv, @school, @amt, @method, @ref, @status, @paid, @remarks, NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@inv", p.InvoiceId), ("@school", p.SchoolId), ("@amt", p.Amount),
            ("@method", p.Method), ("@ref", p.TransactionRef), ("@status", p.Status),
            ("@paid", (object?)p.PaidAt), ("@remarks", p.Remarks));
    }

    public async Task MarkInvoicePaidAsync(long invoiceId, DateTime paidAt, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE platform_invoices SET status='paid', paid_at=@paid WHERE id=@id", ct,
            ("@paid", paidAt), ("@id", invoiceId));
    }

    public async Task SetRemindedAsync(long invoiceId, DateTime remindedAt, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE platform_invoices SET reminded_at=@r WHERE id=@id", ct,
            ("@r", remindedAt), ("@id", invoiceId));
    }

    public async Task<int> OpenTicketsCountAsync(CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return (int)await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM support_tickets WHERE status IN ('open','in_progress','waiting')", ct);
    }

    private static PlatformInvoice Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        SubscriptionId = r.GetLong("subscription_id"),
        InvoiceNo = r.GetString("invoice_no"),
        Amount = r.GetDecimal("amount"),
        TaxAmount = r.GetDecimal("tax_amount"),
        TotalAmount = r.GetDecimal("total_amount"),
        DueDate = r.GetDate("due_date"),
        Status = r.GetString("status"),
        IssuedAt = r.GetDateOrNull("issued_at"),
        PaidAt = r.GetDateOrNull("paid_at"),
        RemindedAt = r.GetDateOrNull("reminded_at"),
        CreatedAt = r.GetDate("created_at"),
        SchoolName = r.GetStringOrNull("school_name"),
    };
}
