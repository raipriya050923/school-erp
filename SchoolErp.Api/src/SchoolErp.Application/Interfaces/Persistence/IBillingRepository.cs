using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IBillingRepository
{
    Task<IReadOnlyList<PlatformInvoice>> GetInvoicesAsync(string? status, CancellationToken ct = default);
    Task<PlatformInvoice?> GetInvoiceByIdAsync(long id, CancellationToken ct = default);
    Task<long> AddPaymentAsync(PlatformPayment payment, CancellationToken ct = default);
    Task MarkInvoicePaidAsync(long invoiceId, DateTime paidAt, CancellationToken ct = default);
    Task SetRemindedAsync(long invoiceId, DateTime remindedAt, CancellationToken ct = default);
    Task<int> OpenTicketsCountAsync(CancellationToken ct = default);
}
