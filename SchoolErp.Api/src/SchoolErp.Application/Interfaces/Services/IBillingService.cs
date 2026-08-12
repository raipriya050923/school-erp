using SchoolErp.Application.DTOs.Billing;

namespace SchoolErp.Application.Interfaces.Services;

public interface IBillingService
{
    Task<IReadOnlyList<InvoiceDto>> ListInvoicesAsync(string? status, CancellationToken ct = default);
    Task<BillingSummaryDto> GetSummaryAsync(CancellationToken ct = default);
    Task RecordPaymentAsync(long invoiceId, RecordPaymentDto dto, CancellationToken ct = default);
    Task SendReminderAsync(long invoiceId, CancellationToken ct = default);
}
