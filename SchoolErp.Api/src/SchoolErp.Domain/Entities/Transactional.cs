namespace SchoolErp.Domain.Entities;

public class DailyAttendance
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long StudentId { get; set; }
    public string? ClassLabel { get; set; }
    public string? SectionLabel { get; set; }
    public DateTime AttendanceDate { get; set; }
    public string Status { get; set; } = "present";
    public string? StudentName { get; set; }   // joined
    public string? RollNo { get; set; }         // joined
}

public class Exam
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Type { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? Classes { get; set; }
    public string Status { get; set; } = "scheduled";
    public List<ExamPaper> Papers { get; set; } = new();
}

public class ExamPaper
{
    public long Id { get; set; }
    public long ExamId { get; set; }
    public string? ClassLabel { get; set; }
    public string Subject { get; set; } = string.Empty;
    public DateTime? ExamDate { get; set; }
    public string? TimeLabel { get; set; }
    public string? Room { get; set; }
    public int FullMarks { get; set; } = 100;
}

public class StudentMark
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long ExamId { get; set; }
    public long StudentId { get; set; }
    public string Subject { get; set; } = string.Empty;
    public decimal? Marks { get; set; }
    public decimal FullMarks { get; set; } = 100;
    public string? StudentName { get; set; }
    public string? RollNo { get; set; }
}

public class TimetableSlot
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string? ClassLabel { get; set; }
    public string? SectionLabel { get; set; }
    public int DayOfWeek { get; set; }
    public int PeriodNo { get; set; }
    public string? TimeLabel { get; set; }
    public string? Subject { get; set; }
    public string? Room { get; set; }
    public long? TeacherStaffId { get; set; }

    public string? TeacherName { get; set; }
}

/// <summary>A period column of the timetable grid. Maps to `timetable_periods`.</summary>
public class TimetablePeriod
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string Name { get; set; } = string.Empty;
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
    public bool IsBreak { get; set; }
    public int SortOrder { get; set; }
}

public class FeeInvoiceRow
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long StudentId { get; set; }
    public string? StudentName { get; set; }
    public string? ClassLabel { get; set; }
    public string? InvoiceNo { get; set; }
    public string? Month { get; set; }
    public decimal Amount { get; set; }
    public decimal Paid { get; set; }
    public DateTime? DueDate { get; set; }
    public string Status { get; set; } = "unpaid";
}

/// <summary>
/// How far marks entry has got for one paper of an exam, in one section. Papers are the unit a
/// teacher actually works through, so this is what the Marks Entry screen counts down.
/// </summary>
public class MarksProgressRow
{
    public string Subject { get; set; } = string.Empty;
    public int FullMarks { get; set; }
    public DateTime? ExamDate { get; set; }
    /// <summary>Students in the section with a mark recorded for this paper.</summary>
    public int Entered { get; set; }
    public int Total { get; set; }
}

/// <summary>
/// A payment a student or parent says they have made, awaiting the school's confirmation.
/// Maps to `fee_payment_submission`. It becomes a <see cref="FeePayment"/> only on verification —
/// until then it is a claim, and counts towards nothing.
/// </summary>
public class FeePaymentSubmission
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long InvoiceId { get; set; }
    public long StudentId { get; set; }

    public decimal Amount { get; set; }
    public string Method { get; set; } = string.Empty;
    public string? Reference { get; set; }
    public DateTime PaidDate { get; set; }
    public string? Note { get; set; }

    /// <summary>pending | verified | rejected</summary>
    public string Status { get; set; } = "pending";

    public long? SubmittedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public long? ReviewedBy { get; set; }
    public DateTime? ReviewedAt { get; set; }
    public string? ReviewNote { get; set; }
    public long? PaymentId { get; set; }

    /* Joined for the admin queue, so a reviewer sees who and what without a second lookup. */
    public string? StudentName { get; set; }
    public string? ClassLabel { get; set; }
    public string? InvoiceNo { get; set; }
    public string? Month { get; set; }
    public decimal InvoiceAmount { get; set; }
    public decimal InvoicePaid { get; set; }
}
