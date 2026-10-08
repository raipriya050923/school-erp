using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class FeeSubmissionRepository : IFeeSubmissionRepository
{
    private readonly IDbConnectionFactory _factory;
    public FeeSubmissionRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = @"
        s.id, s.school_id, s.invoice_id, s.student_id, s.amount, s.method, s.reference,
        s.paid_date, s.note, s.status, s.submitted_by, s.created_at,
        s.reviewed_by, s.reviewed_at, s.review_note, s.payment_id";

    /// <summary>
    /// The invoice is joined in for the queue, so a reviewer sees the month and what is still
    /// owed beside the claim rather than opening each one.
    /// </summary>
    private const string JoinCols = @"
        i.invoice_no, i.month, i.amount AS invoice_amount, i.paid AS invoice_paid,
        i.student_name, i.class_label";

    private const string From = @"
        FROM fee_payment_submission s
        LEFT JOIN fee_invoice i ON i.id = s.invoice_id AND i.school_id = s.school_id";

    public async Task<long> CreateAsync(FeePaymentSubmission s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO fee_payment_submission
              (school_id, invoice_id, student_id, amount, method, reference, paid_date, note,
               status, submitted_by, created_at)
            VALUES (@sid, @inv, @stu, @amt, @method, @ref, @date, @note, 'pending', @by, NOW())";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@sid", s.SchoolId), ("@inv", s.InvoiceId), ("@stu", s.StudentId), ("@amt", s.Amount),
            ("@method", s.Method), ("@ref", s.Reference), ("@date", s.PaidDate.Date),
            ("@note", s.Note), ("@by", (object?)s.SubmittedBy));
    }

    public async Task<FeePaymentSubmission?> GetAsync(long schoolId, long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols}, {JoinCols} {From} WHERE s.school_id=@sid AND s.id=@id";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@sid", schoolId), ("@id", id));
    }

    public async Task<IReadOnlyList<FeePaymentSubmission>> GetForStudentAsync(long schoolId, long studentId,
        CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {Cols}, {JoinCols} {From}
                     WHERE s.school_id=@sid AND s.student_id=@stu
                     ORDER BY s.created_at DESC, s.id DESC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct, ("@sid", schoolId), ("@stu", studentId));
    }

    public async Task<IReadOnlyList<FeePaymentSubmission>> ListAsync(long schoolId, string? status,
        CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var filter = string.IsNullOrWhiteSpace(status) ? "" : " AND s.status=@status";
        // Oldest first: the queue is worked through, so the parent who has waited longest is
        // dealt with first rather than last.
        var sql = $@"SELECT {Cols}, {JoinCols} {From}
                     WHERE s.school_id=@sid{filter}
                     ORDER BY s.status='pending' DESC, s.created_at ASC, s.id ASC";
        return await DbHelper.QueryAsync(conn, sql, Map, ct,
            ("@sid", schoolId), ("@status", (object?)status));
    }

    public async Task<bool> HasPendingForInvoiceAsync(long schoolId, long invoiceId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ScalarLongAsync(conn, @"
            SELECT COUNT(*) FROM fee_payment_submission
            WHERE school_id=@sid AND invoice_id=@inv AND status='pending'", ct,
            ("@sid", schoolId), ("@inv", invoiceId)) > 0;
    }

    public async Task<IReadOnlyList<long>> PendingInvoiceIdsAsync(long schoolId, long studentId,
        CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QueryAsync(conn, @"
            SELECT invoice_id FROM fee_payment_submission
            WHERE school_id=@sid AND student_id=@stu AND status='pending'",
            r => r.GetLong("invoice_id"), ct, ("@sid", schoolId), ("@stu", studentId));
    }

    public async Task<int> MarkReviewedAsync(long schoolId, long id, string status, long reviewedBy,
        string? note, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // Scoped to 'pending' as well as to the id, and the row count is returned rather than
        // discarded: two administrators opening the queue at once must not both be able to
        // settle the same claim, and the caller decides what to do when it loses.
        return await DbHelper.ExecuteAsync(conn, @"
            UPDATE fee_payment_submission
            SET status=@status, reviewed_by=@by, reviewed_at=NOW(), review_note=@note
            WHERE school_id=@sid AND id=@id AND status='pending'", ct,
            ("@status", status), ("@by", reviewedBy), ("@note", note),
            ("@sid", schoolId), ("@id", id));
    }

    public async Task SetPaymentIdAsync(long schoolId, long id, long paymentId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE fee_payment_submission SET payment_id=@pay WHERE school_id=@sid AND id=@id", ct,
            ("@pay", paymentId), ("@sid", schoolId), ("@id", id));
    }

    private static FeePaymentSubmission Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLong("school_id"),
        InvoiceId = r.GetLong("invoice_id"),
        StudentId = r.GetLong("student_id"),
        Amount = r.GetDecimal("amount"),
        Method = r.GetString("method"),
        Reference = r.GetStringOrNull("reference"),
        PaidDate = r.GetDate("paid_date"),
        Note = r.GetStringOrNull("note"),
        Status = r.GetString("status"),
        SubmittedBy = r.GetLongOrNull("submitted_by"),
        CreatedAt = r.GetDate("created_at"),
        ReviewedBy = r.GetLongOrNull("reviewed_by"),
        ReviewedAt = r.GetDateOrNull("reviewed_at"),
        ReviewNote = r.GetStringOrNull("review_note"),
        PaymentId = r.GetLongOrNull("payment_id"),
        InvoiceNo = r.GetStringOrNull("invoice_no"),
        Month = r.GetStringOrNull("month"),
        InvoiceAmount = r.GetDecimal("invoice_amount"),
        InvoicePaid = r.GetDecimal("invoice_paid"),
        StudentName = r.GetStringOrNull("student_name"),
        ClassLabel = r.GetStringOrNull("class_label"),
    };
}
