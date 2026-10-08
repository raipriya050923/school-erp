namespace SchoolErp.Application.DTOs.Billing;

public record InvoiceDto(
    long Id,
    string InvoiceNo,
    long SchoolId,
    string SchoolName,
    decimal TotalAmount,
    DateTime? IssuedAt,
    DateTime DueDate,
    string Status,
    DateTime? PaidAt,
    DateTime? RemindedAt);

public record BillingSummaryDto(
    decimal Collected,
    decimal Outstanding,
    decimal Overdue,
    int PaidCount,
    int SentCount,
    int OverdueCount);

/// <summary>Raises an invoice against a school's current subscription.</summary>
public class RaiseInvoiceDto
{
    public long SchoolId { get; set; }
    /// <summary>Defaults to the subscription's locked-in price when left null or zero.</summary>
    public decimal? Amount { get; set; }
    /// <summary>Defaults to 14 days out when left null.</summary>
    public DateTime? DueDate { get; set; }
}

public class RecordPaymentDto
{
    public decimal Amount { get; set; }
    public string Method { get; set; } = "bank_transfer";
    /// <summary>Required when <see cref="Method"/> is bank_transfer; ignored otherwise.</summary>
    public string? BankName { get; set; }
    public string? TransactionRef { get; set; }
    /// <summary>Path returned by the proof upload endpoint.</summary>
    public string? ProofUrl { get; set; }
    public DateTime PaidAt { get; set; } = DateTime.UtcNow;
    public string? Remarks { get; set; }
}

/// <summary>
/// A school's live entitlement: which plan, how long it has left, and how much
/// of its student allowance is used. Drives the login gate, the admissions cap
/// and the admin console's expiry warning.
/// </summary>
/// <param name="MaxStudents">Null means the plan is unlimited.</param>
/// <param name="DaysRemaining">Negative once the end date has passed.</param>
/// <param name="IsLapsed">True when login should be refused for this school.</param>
public record SubscriptionStatusDto(
    long? PlanId,
    string? PlanName,
    string Status,
    bool IsTrial,
    DateTime? EndDate,
    int? DaysRemaining,
    int StudentCount,
    int? MaxStudents,
    bool AtStudentCap,
    bool IsLapsed,
    string? LapseReason)
{
    /// <summary>Seats left, or null on an unlimited plan.</summary>
    public int? SeatsRemaining => MaxStudents is { } cap ? Math.Max(0, cap - StudentCount) : null;

    /// <summary>
    /// True inside the notice window before expiry, so the console can warn the
    /// admin while they can still do something about it.
    /// </summary>
    public bool IsExpiringSoon =>
        !IsLapsed && DaysRemaining is { } d && d >= 0 && d <= 7;
}
