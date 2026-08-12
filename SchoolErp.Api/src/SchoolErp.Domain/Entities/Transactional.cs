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
