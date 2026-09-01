using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Billing;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

public class BillingService : IBillingService
{
    /// <summary>
    /// Methods the console offers. The `platform_payments.method` ENUM still carries older
    /// gateway values (stripe, esewa, khalti…) so historical rows stay readable, but a new
    /// payment can only be recorded as one of these.
    /// </summary>
    private static readonly string[] PaymentMethods =
        { "bank_transfer", "upi", "debit_card", "credit_card", "cash" };

    private readonly IBillingRepository _billing;
    private readonly INotificationSender _notifier;
    private readonly ISubscriptionRepository _subscriptions;
    private readonly INotificationCenter _bell;

    public BillingService(IBillingRepository billing, INotificationSender notifier,
        ISubscriptionRepository subscriptions, INotificationCenter bell)
    {
        _bell = bell;
        _billing = billing;
        _notifier = notifier;
        _subscriptions = subscriptions;
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

    /// <summary>
    /// Raises an invoice for a school's current subscription. Nothing generates these on a
    /// schedule yet, so a school stays off the billing page until one is raised here — including
    /// schools still inside their trial, which have nothing owed until the trial ends.
    /// </summary>
    public async Task<InvoiceDto> RaiseInvoiceAsync(RaiseInvoiceDto dto, CancellationToken ct = default)
    {
        var sub = await _subscriptions.GetCurrentBySchoolAsync(dto.SchoolId, ct)
                  ?? throw new ValidationException("This school has no subscription to invoice.");

        var open = await _billing.GetInvoicesBySubscriptionAsync(sub.Id, ct);
        if (open.Any(i => i.Status is "sent" or "overdue" or "draft"))
            throw new ValidationException("This subscription already has an unpaid invoice. Settle or void it first.");

        var amount = dto.Amount is > 0 ? dto.Amount.Value : sub.Price;
        if (amount <= 0)
            throw new ValidationException("Invoice amount must be greater than zero.");

        var invoice = new PlatformInvoice
        {
            SchoolId = dto.SchoolId,
            SubscriptionId = sub.Id,
            InvoiceNo = await _billing.NextInvoiceNoAsync(ct),
            Amount = amount,
            TaxAmount = 0m,
            TotalAmount = amount,
            DueDate = (dto.DueDate ?? DateTime.UtcNow.Date.AddDays(14)).Date,
            // Raised by hand from the console, so it is issued immediately rather than left a draft.
            Status = "sent",
            IssuedAt = DateTime.UtcNow,
        };
        invoice.Id = await _billing.CreateInvoiceAsync(invoice, ct);

        var saved = await _billing.GetInvoiceByIdAsync(invoice.Id, ct) ?? invoice;
        return new InvoiceDto(saved.Id, saved.InvoiceNo, saved.SchoolId, saved.SchoolName ?? "",
            saved.TotalAmount, saved.IssuedAt, saved.DueDate, saved.Status, saved.PaidAt, saved.RemindedAt);
    }

    public async Task RecordPaymentAsync(long invoiceId, RecordPaymentDto dto, CancellationToken ct = default)
    {
        var inv = await _billing.GetInvoiceByIdAsync(invoiceId, ct)
                  ?? throw new NotFoundException($"Invoice {invoiceId} not found.");
        if (inv.Status == "paid")
            throw new ValidationException("Invoice is already paid.");
        if (dto.Amount <= 0)
            throw new ValidationException("Payment amount must be greater than zero.");

        var method = (dto.Method ?? "").Trim().ToLowerInvariant();
        if (!PaymentMethods.Contains(method))
            throw new ValidationException($"'{dto.Method}' is not a supported payment method.");

        // A bank transfer without the bank is unreconcilable later, so it is required here
        // rather than left to the UI.
        var bankName = string.IsNullOrWhiteSpace(dto.BankName) ? null : dto.BankName.Trim();
        if (method == "bank_transfer" && bankName is null)
            throw new ValidationException("Bank name is required for a bank transfer.");
        if (method != "bank_transfer") bankName = null;

        var payment = new PlatformPayment
        {
            InvoiceId = inv.Id,
            SchoolId = inv.SchoolId,
            Amount = dto.Amount,
            Method = method,
            BankName = bankName,
            TransactionRef = dto.TransactionRef,
            ProofUrl = string.IsNullOrWhiteSpace(dto.ProofUrl) ? null : dto.ProofUrl.Trim(),
            Status = "success",
            PaidAt = dto.PaidAt,
            Remarks = dto.Remarks,
        };
        await _billing.AddPaymentAsync(payment, ct);
        await _billing.MarkInvoicePaidAsync(inv.Id, dto.PaidAt, ct);

        await _bell.NotifyRoleAsync(null, "super_admin",
            "Subscription payment received",
            $"{inv.SchoolName} paid {inv.TotalAmount:N0} against {inv.InvoiceNo} ({dto.Method.Replace('_', ' ')}).",
            "fee", "platform_invoices", inv.Id, ct);

        // Paying is what turns a trial (or a lapsed subscription) into a paying one — without this
        // the school could settle its invoice and still read as 'trial' forever.
        await ActivateSubscriptionAsync(inv.SubscriptionId, dto.PaidAt, ct);
    }

    /// <summary>
    /// Moves the invoice's subscription to <c>active</c> for a full billing period starting at the
    /// payment date. Late payers therefore get their whole period from when they paid rather than
    /// losing the lapsed days; the billing anniversary shifts with them.
    /// </summary>
    private async Task ActivateSubscriptionAsync(long subscriptionId, DateTime paidAt, CancellationToken ct)
    {
        var sub = await _subscriptions.GetByIdAsync(subscriptionId, ct);
        if (sub is null) return;   // invoice with no live subscription — nothing to advance
        if (sub.Status is "cancelled") return;   // a deliberate cancellation is not undone by a payment

        var start = paidAt.Date;
        var end = sub.BillingCycle == "monthly" ? start.AddMonths(1) : start.AddYears(1);
        await _subscriptions.ActivateAsync(sub.Id, start, end, ct);
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
