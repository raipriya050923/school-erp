using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Billing;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

public class BillingService : IBillingService
{
    private readonly IBillingRepository _billing;
    private readonly INotificationSender _notifier;

    public BillingService(IBillingRepository billing, INotificationSender notifier)
    {
        _billing = billing;
        _notifier = notifier;
    }

    public async Task<IReadOnlyList<InvoiceDto>> ListInvoicesAsync(string? status, CancellationToken ct = default)
    {
        var rows = await _billing.GetInvoicesAsync(status, ct);
        return rows.Select(i => new InvoiceDto(
            i.Id, i.InvoiceNo, i.SchoolId, i.SchoolName ?? "", i.TotalAmount,
            i.IssuedAt, i.DueDate, i.Status, i.PaidAt, i.RemindedAt)).ToList();
    }

    public async Task<BillingSummaryDto> GetSummaryAsync(CancellationToken ct = default)
    {
        var all = await _billing.GetInvoicesAsync(null, ct);
        decimal Collected(string s) => all.Where(i => i.Status == s).Sum(i => i.TotalAmount);
        int Count(string s) => all.Count(i => i.Status == s);
        return new BillingSummaryDto(
            Collected("paid"),
            Collected("sent"),
            Collected("overdue"),
            Count("paid"), Count("sent"), Count("overdue"));
    }

    public async Task RecordPaymentAsync(long invoiceId, RecordPaymentDto dto, CancellationToken ct = default)
    {
        var inv = await _billing.GetInvoiceByIdAsync(invoiceId, ct)
                  ?? throw new NotFoundException($"Invoice {invoiceId} not found.");
        if (inv.Status == "paid")
            throw new ValidationException("Invoice is already paid.");
        if (dto.Amount <= 0)
            throw new ValidationException("Payment amount must be greater than zero.");

        var payment = new PlatformPayment
        {
            InvoiceId = inv.Id,
            SchoolId = inv.SchoolId,
            Amount = dto.Amount,
            Method = dto.Method,
            TransactionRef = dto.TransactionRef,
            Status = "success",
            PaidAt = dto.PaidAt,
            Remarks = dto.Remarks,
        };
        await _billing.AddPaymentAsync(payment, ct);
        await _billing.MarkInvoicePaidAsync(inv.Id, dto.PaidAt, ct);
    }

    public async Task SendReminderAsync(long invoiceId, CancellationToken ct = default)
    {
        var inv = await _billing.GetInvoiceByIdAsync(invoiceId, ct)
                  ?? throw new NotFoundException($"Invoice {invoiceId} not found.");
        var email = $"billing@{(inv.SchoolName ?? "school").ToLowerInvariant().Replace(' ', '-')}.edu.np";
        await _notifier.SendEmailAsync(email,
            $"Payment reminder — invoice {inv.InvoiceNo}",
            $"Your invoice {inv.InvoiceNo} of {inv.TotalAmount:C} is due on {inv.DueDate:d}.", ct);
        await _billing.SetRemindedAsync(inv.Id, DateTime.UtcNow, ct);
    }
}
