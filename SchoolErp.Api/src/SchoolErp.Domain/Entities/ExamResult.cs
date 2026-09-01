namespace SchoolErp.Domain.Entities;

/// <summary>
/// A student's standing in one exam, as computed when marks were last saved. Stored rather than
/// derived at read time so a result can be cited: the sheet a parent was shown does not change
/// because a mark was corrected afterwards without anyone noticing.
/// </summary>
public class ExamResultRow
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long ExamId { get; set; }
    public long StudentId { get; set; }
    /// <summary>Where they sat the exam, kept even if they later move section.</summary>
    public string? ClassLabel { get; set; }
    public string? SectionLabel { get; set; }
    public decimal Obtained { get; set; }
    /// <summary>Total of every paper for the class, marked or not.</summary>
    public decimal FullMarks { get; set; }
    public decimal Percent { get; set; }
    public string? Grade { get; set; }
    public int SubjectsTotal { get; set; }
    public int SubjectsEntered { get; set; }
    /// <summary>
    /// False while any paper is unmarked. The percentage is still real, but provisional: it is
    /// scored over the full paper total, so it can only rise as the remaining marks arrive.
    /// </summary>
    public bool IsComplete { get; set; }
    public DateTime ComputedAt { get; set; }

    /// <summary>Not stored — the student's name and roll, joined in for display.</summary>
    public string? StudentName { get; set; }
    public string? RollNo { get; set; }
}

/// <summary>One band of a school's grade scale. Maps to `grade_scales`.</summary>
public class GradeBand
{
    public string Grade { get; set; } = string.Empty;
    public decimal MinPercent { get; set; }
    public decimal MaxPercent { get; set; }
    public decimal? GradePoint { get; set; }
    public string? Remarks { get; set; }
}

/// <summary>
/// Whether a section's result sheet has been signed off by its class teacher. An admin may only
/// publish an exam once every section that sat it is approved.
/// </summary>
public class ExamSectionApproval
{
    public long ExamId { get; set; }
    public string ClassLabel { get; set; } = string.Empty;
    public string SectionLabel { get; set; } = string.Empty;
    public string Status { get; set; } = "pending";
    public long? ApprovedBy { get; set; }
    public string? ApprovedByName { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public string? Remarks { get; set; }
    /// <summary>Students in the section, and how many have every paper marked.</summary>
    public int StudentCount { get; set; }
    public int CompleteCount { get; set; }
}
