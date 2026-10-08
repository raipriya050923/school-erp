namespace SchoolErp.Domain.Entities;

/// <summary>
/// One distance band and what it costs a month. Maps to `transport_slabs`.
///
/// A band is described by its ceiling alone: "up to 6 km" starts wherever the band below it
/// ended. Storing both ends would let a school save a set with a hole between 6 and 8 km, or an
/// overlap, and then wonder why a student at 7 km is not billed.
/// </summary>
public class TransportSlab
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long AcademicYearId { get; set; }
    public long FeeTypeId { get; set; }
    public decimal UpToKm { get; set; }
    public decimal Amount { get; set; }
}

/// <summary>
/// What one student's transport costs. Maps to `student_transport`, one row per student.
///
/// The row survives a student giving up the bus (<see cref="IsActive"/> goes to false) because
/// the distance and the pickup point are facts about where they live, and re-entering them every
/// term is how they end up wrong.
/// </summary>
public class StudentTransport
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long StudentId { get; set; }
    public bool IsActive { get; set; } = true;
    /// <summary>Distance from the school, one way. Null means nobody has measured it yet.</summary>
    public decimal? DistanceKm { get; set; }
    public string? PickupPoint { get; set; }
    /// <summary>
    /// A negotiated monthly amount that ignores the slabs. Null leaves the slab in charge —
    /// which is not the same as an override of zero, meaning this student rides free.
    /// </summary>
    public decimal? AmountOverride { get; set; }
    public string? Note { get; set; }
}

/// <summary>Why a rider produced no transport charge, so the screen can say something useful.</summary>
public enum TransportFeeStatus
{
    /// <summary>An amount was worked out and is ready to bill.</summary>
    Priced,
    /// <summary>The student does not use transport; no line belongs on their invoice.</summary>
    NotRiding,
    /// <summary>They ride, but nobody has recorded how far.</summary>
    NoDistance,
    /// <summary>They ride, but their distance is past the last band the school has priced.</summary>
    BeyondSlabs,
    /// <summary>They ride and the distance is known, but no bands exist at all.</summary>
    NoSlabs,
}

/// <summary>What one student owes for transport, and why.</summary>
public record TransportFee(TransportFeeStatus Status, decimal Amount, decimal? MatchedSlabKm)
{
    public bool IsBillable => Status == TransportFeeStatus.Priced;
}

/// <summary>
/// Turns a distance into an amount. Lives in the domain because two callers must agree exactly:
/// the admin screen that previews what each student will be charged, and the invoice run that
/// charges it. Two implementations of this rule would eventually disagree by a slab.
/// </summary>
public static class TransportPricing
{
    /// <summary>
    /// The band a distance falls in: the cheapest ceiling that still covers it. A distance equal
    /// to a ceiling belongs to that band — "up to 6 km" includes 6.
    /// </summary>
    public static TransportFee Resolve(StudentTransport? assignment, IReadOnlyList<TransportSlab> slabs)
    {
        if (assignment is null || !assignment.IsActive)
            return new TransportFee(TransportFeeStatus.NotRiding, 0m, null);

        // Checked before the distance: an agreed amount is agreed whatever the distance turns out
        // to be, and a rider on a negotiated rate should not be reported as missing a measurement.
        if (assignment.AmountOverride is { } agreed)
            return new TransportFee(TransportFeeStatus.Priced, decimal.Round(agreed, 2), null);

        if (assignment.DistanceKm is not { } km)
            return new TransportFee(TransportFeeStatus.NoDistance, 0m, null);
        if (slabs.Count == 0)
            return new TransportFee(TransportFeeStatus.NoSlabs, 0m, null);

        var band = slabs.Where(s => s.UpToKm >= km).OrderBy(s => s.UpToKm).FirstOrDefault();
        return band is null
            // Deliberately not billed at the top band: a student 30 km out on a 20 km scale is a
            // gap in the pricing, and quietly charging them the 20 km fare hides it for a year.
            ? new TransportFee(TransportFeeStatus.BeyondSlabs, 0m, null)
            : new TransportFee(TransportFeeStatus.Priced, band.Amount, band.UpToKm);
    }
}
