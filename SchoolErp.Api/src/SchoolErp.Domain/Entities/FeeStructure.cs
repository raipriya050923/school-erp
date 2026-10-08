namespace SchoolErp.Domain.Entities;

/// <summary>
/// A charge a school levies — Tuition Fee, Transport Fee, and so on. Maps to `fee_types`,
/// unique per (school_id, name). Heads are retired rather than deleted: invoice lines point at
/// them, and a deleted head would leave past invoices unable to say what they billed for.
/// </summary>
public class FeeHead
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    /// <summary>one_time | monthly | quarterly | half_yearly | yearly.</summary>
    public string Frequency { get; set; } = "monthly";
    /// <summary>
    /// Where the amount comes from: <c>class</c> reads the class price grid, <c>distance</c>
    /// reads the student's own distance and the school's band scale. A head cannot be both — the
    /// two would have to be added together, and no school bills transport twice.
    /// </summary>
    public string PricingMode { get; set; } = "class";
    public bool IsRefundable { get; set; }
    public bool IsActive { get; set; } = true;
}

/// <summary>
/// What one class pays for one head in one academic year. Maps to `fee_structures`, unique per
/// (academic_year_id, class_id, fee_type_id). `Frequency` is copied down from the head so the
/// invoice run can read a single table.
/// </summary>
public class FeeStructureCell
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long AcademicYearId { get; set; }
    public long ClassId { get; set; }
    public string ClassName { get; set; } = string.Empty;
    public long FeeTypeId { get; set; }
    public string HeadName { get; set; } = string.Empty;
    public string Frequency { get; set; } = "monthly";
    public decimal Amount { get; set; }
}

/// <summary>
/// One payment against an invoice, with enough of the invoice and the student alongside it to
/// print a receipt without three more round trips.
/// <paramref name="PaidToDate"/> counts this payment and every earlier one on the same invoice,
/// so a reprint of an old receipt still shows what was outstanding at that point.
/// </summary>
public record FeePaymentRow(
    long Id, long InvoiceId, long SchoolId, decimal Amount, string? Method, string? Reference,
    DateTime? PaidDate, DateTime CreatedAt,
    string? InvoiceNo, string? Month, decimal InvoiceTotal, decimal PaidToDate,
    long StudentId, string? StudentName, string? AdmissionNo, string? ClassLabel);

/// <summary>One head's contribution to an invoice, kept so the total can be explained later.</summary>
public class FeeInvoiceLine
{
    public long Id { get; set; }
    public long InvoiceId { get; set; }
    public long? FeeTypeId { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
}

/// <summary>
/// Outcome of an invoice run. <see cref="UnpricedClasses"/> names classes that were skipped
/// because the fee structure has no amounts for them — silently generating nothing is the one
/// behaviour that would leave an admin unable to tell what went wrong.
/// </summary>
/// <param name="TransportSkipped">
/// Riders whose transport could not be priced — no distance recorded, or a distance past the last
/// band. Reported apart from <see cref="FeeGenerationResult.UnpricedClasses"/> because the fix is
/// different: these students were invoiced, just without their bus.
/// </param>
/// <param name="RepeatChargesSkipped">
/// How many one-time or yearly charges were left off because that student had already been
/// billed for them. Reported so that ticking the box and seeing no change reads as the rule
/// working, rather than as the run having quietly failed.
/// </param>
/// <param name="ToppedUp">
/// Invoices that already existed for the month and gained the yearly or one-time charges they
/// were missing. Counted apart from <see cref="FeeGenerationResult.Created"/>: nothing new was
/// raised, an existing bill grew.
/// </param>
public record FeeGenerationResult(
    int Created, int AlreadyBilled, IReadOnlyList<string> UnpricedClasses,
    IReadOnlyList<string> TransportSkipped, int RepeatChargesSkipped, int ToppedUp);
