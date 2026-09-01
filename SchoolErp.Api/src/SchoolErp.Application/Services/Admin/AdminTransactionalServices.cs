using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Transactional;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.Admin;

public class AdminAttendanceService : IAdminAttendanceService
{
    private readonly IAttendanceRepository _repo;
    private readonly IStudentRepository _students;
    private readonly ICurrentSchool _school;

    public AdminAttendanceService(IAttendanceRepository repo, IStudentRepository students, ICurrentSchool school)
    {
        _repo = repo;
        _students = students;
        _school = school;
    }

    public async Task<IReadOnlyList<AttendanceRowDto>> GetAsync(string className, string sectionName, DateTime date, CancellationToken ct = default)
    {
        var rows = await _repo.GetSectionAsync(_school.SchoolId, className, sectionName, date, ct);
        return rows.Select(r => new AttendanceRowDto(r.StudentId, r.RollNo, r.StudentName ?? "", r.Status)).ToList();
    }

    public Task SaveAsync(SaveAttendanceDto dto, CancellationToken ct = default)
        => _repo.UpsertAsync(_school.SchoolId, dto.ClassName, dto.SectionName, dto.Date,
            dto.Entries.Select(e => (e.StudentId, e.Status)), ct);

    public async Task<AttendanceReportDto> ReportAsync(long studentId, DateTime from, DateTime to, CancellationToken ct = default)
    {
        if (from > to) throw new ValidationException("From date must be on or before To date.");
        var student = await _students.GetByIdAsync(_school.SchoolId, studentId, ct)
                      ?? throw new NotFoundException("Student not found.");
        var rows = await _repo.GetStudentRangeAsync(_school.SchoolId, studentId, from, to, ct);
        var byDate = rows.ToDictionary(r => r.AttendanceDate.Date, r => r.Status);

        var days = new List<AttendanceDayDto>();
        int present = 0, absent = 0, late = 0, school = 0;
        var names = new[] { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };
        for (var d = from.Date; d <= to.Date; d = d.AddDays(1))
        {
            string status;
            if (d.DayOfWeek == DayOfWeek.Saturday) status = "Holiday";
            else if (byDate.TryGetValue(d, out var s)) status = Cap(s);
            else status = "—";  // no record

            if (status is "Present") { present++; school++; }
            else if (status is "Late") { late++; school++; }
            else if (status is "Absent") { absent++; school++; }

            days.Add(new AttendanceDayDto(d.ToString("yyyy-MM-dd"), names[(int)d.DayOfWeek], status));
        }
        var pct = school == 0 ? 0 : (int)Math.Round((present + late) / (double)school * 100);
        return new AttendanceReportDto($"{student.FirstName} {student.LastName}".Trim(), present, absent, late, school, pct, days);
    }

    private static string Cap(string s) => string.IsNullOrEmpty(s) ? s : char.ToUpper(s[0]) + s[1..];
}

public class AdminExamService : IAdminExamService
{
    private readonly IExamRepository _repo;
    private readonly IExamResultRepository _results;
    private readonly ICurrentSchool _school;

    public AdminExamService(IExamRepository repo, IExamResultRepository results, ICurrentSchool school)
    {
        _repo = repo;
        _results = results;
        _school = school;
    }

    public async Task<IReadOnlyList<ExamApprovalDto>> ApprovalsAsync(long examId, CancellationToken ct = default)
    {
        _ = await _repo.GetAsync(_school.SchoolId, examId, ct)
            ?? throw new NotFoundException($"Exam {examId} not found.");
        var rows = await _results.GetExamApprovalsAsync(_school.SchoolId, examId, ct);
        return rows.Select(a => new ExamApprovalDto(
            a.ClassLabel, a.SectionLabel, a.Status, a.ApprovedByName, a.ApprovedAt, a.Remarks,
            a.StudentCount, a.CompleteCount)).ToList();
    }

    public async Task SetStatusAsync(long examId, string status, CancellationToken ct = default)
    {
        if (!ExamStatus.Settable.Contains(status))
            throw new ValidationException(
                $"'{status}' is not a valid exam status. Use one of: {string.Join(", ", ExamStatus.Settable)}.");
        _ = await _repo.GetAsync(_school.SchoolId, examId, ct)
            ?? throw new NotFoundException($"Exam {examId} not found.");

        // Publishing is the one status a school cannot take back cleanly — students see the marks
        // the moment it is set — so it waits on every class teacher having signed their section
        // off. Any other status change is the admin's to make freely.
        if (status == "result_published")
        {
            var approvals = await _results.GetExamApprovalsAsync(_school.SchoolId, examId, ct);
            if (approvals.Count == 0)
                throw new ValidationException("This exam has no papers for any class, so there is nothing to publish.");
            var waiting = approvals.Where(a => a.Status != "approved").ToList();
            if (waiting.Count > 0)
                throw new ValidationException(
                    "Results cannot be published until every class teacher has approved their section. " +
                    $"Still waiting on: {string.Join(", ", waiting.Select(a => $"{a.ClassLabel}-{a.SectionLabel}"))}.");
        }

        await _repo.SetStatusAsync(_school.SchoolId, examId, status, ct);
    }

    public async Task<IReadOnlyList<ExamDto>> ListAsync(CancellationToken ct = default)
    {
        var exams = await _repo.GetAllWithPapersAsync(_school.SchoolId, ct);
        return exams.Select(e => new ExamDto(e.Id, e.Name, e.Type, e.StartDate, e.EndDate, e.Classes, ExamStatus.Effective(e),
            ExamStatus.IsManual(e), ExamStatus.FromDates(e),
            e.Papers.Count, e.Papers.Select(p => new ExamPaperDto(p.Id, p.ClassLabel, p.Subject, p.ExamDate, p.TimeLabel, p.Room, p.FullMarks)).ToList())).ToList();
    }

    public async Task<long> CreateExamAsync(CreateExamDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        return await _repo.CreateExamAsync(new Exam
        {
            SchoolId = _school.SchoolId, Name = dto.Name.Trim(), Type = dto.Type,
            StartDate = dto.StartDate, EndDate = dto.EndDate,
            Classes = string.IsNullOrWhiteSpace(dto.Classes) ? "All" : dto.Classes,
        }, ct);
    }

    public async Task UpdateExamAsync(long id, CreateExamDto dto, CancellationToken ct = default)
    {
        Validate(dto);
        var exam = await _repo.GetAsync(_school.SchoolId, id, ct)
                   ?? throw new NotFoundException($"Exam {id} not found.");
        exam.Name = dto.Name.Trim();
        exam.Type = dto.Type;
        exam.StartDate = dto.StartDate;
        exam.EndDate = dto.EndDate;
        exam.Classes = string.IsNullOrWhiteSpace(dto.Classes) ? exam.Classes : dto.Classes;
        await _repo.UpdateExamAsync(exam, ct);
    }

    public async Task DeleteExamAsync(long id, CancellationToken ct = default)
    {
        _ = await _repo.GetAsync(_school.SchoolId, id, ct)
            ?? throw new NotFoundException($"Exam {id} not found.");
        await _repo.DeleteExamAsync(_school.SchoolId, id, ct);
    }

    private static void Validate(CreateExamDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Name)) throw new ValidationException("Exam name is required.");
        if (dto.StartDate.HasValue && dto.EndDate.HasValue && dto.StartDate > dto.EndDate)
            throw new ValidationException("Start date must be on or before the end date.");
    }

    public async Task<AddPapersResultDto> AddPaperAsync(SaveExamPaperDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Subject)) throw new ValidationException("Subject is required.");

        // The exam id arrives from the client and was never checked against this school. A paper
        // could be filed against another school's exam, or against one that no longer exists —
        // exam_paper carries no foreign key, so nothing at the database level refused it.
        _ = await _repo.GetAsync(_school.SchoolId, dto.ExamId, ct)
            ?? throw new NotFoundException($"Exam {dto.ExamId} not found.");

        var classes = (dto.ClassLabels.Count > 0 ? dto.ClassLabels : new List<string> { dto.ClassLabel ?? "" })
            .Select(c => c?.Trim() ?? "")
            .Where(c => c.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        if (classes.Count == 0)
            throw new ValidationException("Class is required — a paper is scheduled for one class.");

        var subject = dto.Subject.Trim();
        var scheduled = new List<string>();
        var already = new List<string>();
        foreach (var classLabel in classes)
        {
            // Skipped, not failed: scheduling a subject across the school should not stop at the
            // first class that already has it.
            if (await _repo.PaperSubjectExistsAsync(dto.ExamId, classLabel, subject, ct))
            {
                already.Add(classLabel);
                continue;
            }
            await _repo.AddPaperAsync(new ExamPaper
            {
                ExamId = dto.ExamId, ClassLabel = classLabel, Subject = subject,
                ExamDate = dto.ExamDate, TimeLabel = dto.Time, Room = dto.Room, FullMarks = dto.FullMarks,
            }, ct);
            scheduled.Add(classLabel);
        }

        // Nothing done and nothing to do is worth saying out loud; the dialog would otherwise
        // close on a silent no-op.
        if (scheduled.Count == 0)
            throw new ValidationException(
                $"{subject} is already scheduled for {string.Join(", ", already)} in this exam.");

        return new AddPapersResultDto(scheduled.Count, scheduled, already);
    }

    public Task DeletePaperAsync(long paperId, CancellationToken ct = default)
        => _repo.DeletePaperAsync(_school.SchoolId, paperId, ct);
}

public class AdminFeeService : IAdminFeeService
{
    private readonly IFeeRepository _repo;
    private readonly ICurrentSchool _school;

    public AdminFeeService(IFeeRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    public async Task<IReadOnlyList<FeeInvoiceDto>> ListAsync(string? status, CancellationToken ct = default)
    {
        // Bring due dates up to date first, so the Overdue filter reflects today rather than
        // whatever the rows were last written as.
        await _repo.MarkOverdueAsync(_school.SchoolId, ct);
        var rows = await _repo.GetInvoicesAsync(_school.SchoolId, status, ct);
        return rows.Select(ToDto).ToList();
    }

    public async Task<FeeSummaryDto> SummaryAsync(CancellationToken ct = default)
    {
        await _repo.MarkOverdueAsync(_school.SchoolId, ct);
        var all = await _repo.GetInvoicesAsync(_school.SchoolId, null, ct);
        var billed = all.Sum(i => i.Amount);
        var collected = all.Sum(i => i.Paid);
        // Anything not fully settled is outstanding — overdue invoices are still owed, so counting
        // only 'unpaid'/'partial' would understate the figure the Outstanding tile sits above.
        return new FeeSummaryDto(billed, collected, billed - collected,
            all.Count(i => i.Status != "paid"), all.Count(i => i.Status == "overdue"));
    }

    public async Task RecordPaymentAsync(long invoiceId, RecordFeePaymentDto dto, CancellationToken ct = default)
    {
        var inv = await _repo.GetInvoiceAsync(_school.SchoolId, invoiceId, ct)
                  ?? throw new NotFoundException("Invoice not found.");
        if (inv.Status == "paid") throw new ValidationException("Invoice is already paid.");
        if (dto.Amount <= 0) throw new ValidationException("Amount must be greater than zero.");
        if (dto.Amount > inv.Amount - inv.Paid) throw new ValidationException("Amount exceeds the balance.");
        await _repo.RecordPaymentAsync(_school.SchoolId, invoiceId, dto.Amount, dto.Method, dto.Ref, dto.PaymentDate, ct);
    }

    public async Task<IReadOnlyList<FeeInvoiceLineDto>> LinesAsync(long invoiceId, CancellationToken ct = default)
    {
        var inv = await _repo.GetInvoiceAsync(_school.SchoolId, invoiceId, ct)
                  ?? throw new NotFoundException("Invoice not found.");
        var lines = await _repo.GetInvoiceLinesAsync(_school.SchoolId, invoiceId, ct);
        // Invoices raised before the fee structure existed have no lines. Rather than show an
        // empty breakdown, present the total as the single charge it effectively was.
        return lines.Count > 0
            ? lines.Select(l => new FeeInvoiceLineDto(l.Description, l.Amount)).ToList()
            : new List<FeeInvoiceLineDto> { new("School fee", inv.Amount) };
    }

    public async Task<GenerateInvoicesResultDto> GenerateAsync(GenerateInvoicesDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Month)) throw new ValidationException("Billing month is required.");
        var r = await _repo.GenerateAsync(_school.SchoolId, dto.Month.Trim(), dto.DueDate, dto.ClassName, dto.IncludeOneOff, ct);
        return new GenerateInvoicesResultDto(r.Created, r.AlreadyBilled, r.UnpricedClasses);
    }

    private static FeeInvoiceDto ToDto(FeeInvoiceRow i) => new(
        i.Id, i.InvoiceNo, i.StudentName, i.ClassLabel, i.Month, i.Amount, i.Paid, i.Amount - i.Paid, i.DueDate, i.Status);
}
