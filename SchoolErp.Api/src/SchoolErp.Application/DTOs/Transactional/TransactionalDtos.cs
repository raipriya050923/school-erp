namespace SchoolErp.Application.DTOs.Transactional;

/* -------- attendance -------- */
public record AttendanceRowDto(long StudentId, string? RollNo, string Name, string Status);

public class SaveAttendanceDto
{
    public string ClassName { get; set; } = string.Empty;
    public string SectionName { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public List<AttendanceEntry> Entries { get; set; } = new();
}
public class AttendanceEntry { public long StudentId { get; set; } public string Status { get; set; } = "present"; }

public record AttendanceDayDto(string Date, string Day, string Status);
public record AttendanceReportDto(
    string StudentName, int Present, int Absent, int Late, int SchoolDays, int Percent,
    IReadOnlyList<AttendanceDayDto> Days);

/* -------- exams -------- */
public record ExamPaperDto(long Id, string? ClassLabel, string Subject, DateTime? ExamDate, string? Time, string? Room, int FullMarks);
public record ExamDto(long Id, string Name, string? Type, DateTime? StartDate, DateTime? EndDate, string? Classes, string Status, int PaperCount, IReadOnlyList<ExamPaperDto> Papers);
public class CreateExamDto { public string Name { get; set; } = ""; public string? Type { get; set; } public DateTime? StartDate { get; set; } public DateTime? EndDate { get; set; } public string? Classes { get; set; } }
public class SaveExamPaperDto { public long ExamId { get; set; } public string? ClassLabel { get; set; } public string Subject { get; set; } = ""; public DateTime? ExamDate { get; set; } public string? Time { get; set; } public string? Room { get; set; } public int FullMarks { get; set; } = 100; }

/* -------- marks -------- */
public record MarkRowDto(long StudentId, string? RollNo, string Name, decimal? Marks);
public class SaveMarksDto
{
    public long ExamId { get; set; }
    public string ClassName { get; set; } = "";
    public string SectionName { get; set; } = "";
    public string Subject { get; set; } = "";
    public int FullMarks { get; set; } = 100;
    public List<MarkEntry> Entries { get; set; } = new();
}
public class MarkEntry { public long StudentId { get; set; } public decimal? Marks { get; set; } }

/* -------- timetable -------- */
public record TimetableSlotDto(int DayOfWeek, int PeriodNo, string? Time, string? Label, string? Room);

/* -------- fees -------- */
public record FeeInvoiceDto(long Id, string? InvoiceNo, string? StudentName, string? ClassLabel, string? Month, decimal Amount, decimal Paid, decimal Balance, DateTime? DueDate, string Status);
public record FeeSummaryDto(decimal TotalBilled, decimal Collected, decimal Outstanding, int Unpaid, int Overdue);
public class RecordFeePaymentDto { public decimal Amount { get; set; } public string Method { get; set; } = "cash"; public string? Ref { get; set; } public DateTime PaymentDate { get; set; } = DateTime.UtcNow; }
public class GenerateInvoicesDto { public string Month { get; set; } = ""; public DateTime DueDate { get; set; } public string ClassName { get; set; } = "All"; }
