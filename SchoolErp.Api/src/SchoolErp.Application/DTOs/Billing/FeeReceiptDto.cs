namespace SchoolErp.Application.DTOs.Billing;

/// <summary>One payment on an invoice, as the payment list shows it before a receipt is opened.</summary>
public record FeePaymentDto(
    long Id, string ReceiptNo, decimal Amount, string? Method, string? Reference,
    DateTime? PaidDate, decimal BalanceAfter);

/// <summary>One head's share of what the invoice was raised for, reprinted on the receipt.</summary>
public record ReceiptLineDto(string Description, decimal Amount);

/// <summary>
/// A receipt for one payment.
///
/// Per payment, not per invoice: a family paying a term's fees in two instalments needs two
/// receipts, each showing what they handed over that day and what was still outstanding
/// afterwards. One receipt per invoice would be unissuable until the invoice was settled, which
/// is exactly when the payer least needs it.
/// </summary>
public record FeeReceiptDto(
    /* ---- who issued it ---- */
    string SchoolName,
    string? SchoolAddress,
    string? SchoolPhone,
    string? SchoolEmail,

    /* ---- the receipt itself ---- */
    long PaymentId,
    string ReceiptNo,
    DateTime? PaidDate,
    DateTime IssuedAt,

    /* ---- who paid ---- */
    string StudentName,
    string? AdmissionNo,
    string? ClassLabel,

    /* ---- what it was for ---- */
    string? InvoiceNo,
    string? Month,
    IReadOnlyList<ReceiptLineDto> Lines,

    /* ---- the money ---- */
    decimal AmountPaid,
    /// <summary>The amount in words, so a figure cannot be altered after the fact.</summary>
    string AmountInWords,
    string? Method,
    string? Reference,

    /// <summary>
    /// The invoice total as it stands now, with what had been paid up to and including this
    /// receipt, and what was left afterwards. Taken from the invoice's current total rather than
    /// a frozen copy — the system keeps no history of it — so a later top-up changes what a
    /// reprint says. That is why the balance is labelled as at the time of printing.
    /// </summary>
    decimal InvoiceTotal,
    decimal PaidToDate,
    decimal BalanceAfter);
