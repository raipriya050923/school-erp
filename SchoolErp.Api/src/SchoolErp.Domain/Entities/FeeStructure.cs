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
public record FeeGenerationResult(int Created, int AlreadyBilled, IReadOnlyList<string> UnpricedClasses);
