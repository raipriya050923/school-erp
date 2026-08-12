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
    private readonly ICurrentSchool _school;

    public AdminExamService(IExamRepository repo, ICurrentSchool school)
    {
        _repo = repo;
        _school = school;
    }

    public async Task<IReadOnlyList<ExamDto>> ListAsync(CancellationToken ct = default)
    {
        var exams = await _repo.GetAllWithPapersAsync(_school.SchoolId, ct);
        return exams.Select(e => new ExamDto(e.Id, e.Name, e.Type, e.StartDate, e.EndDate, e.Classes, e.Status,
            e.Papers.Count, e.Papers.Select(p => new ExamPaperDto(p.Id, p.ClassLabel, p.Subject, p.ExamDate, p.TimeLabel, p.Room, p.FullMarks)).ToList())).ToList();
    }

    public async Task<long> CreateExamAsync(CreateExamDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Name)) throw new ValidationException("Exam name is required.");
        if (dto.StartDate.HasValue && dto.EndDate.HasValue && dto.StartDate > dto.EndDate)
            throw new ValidationException("Start date must be on or before the end date.");
        return await _repo.CreateExamAsync(new Exam
        {
            SchoolId = _school.SchoolId, Name = dto.Name.Trim(), Type = dto.Type,
            StartDate = dto.StartDate, EndDate = dto.EndDate,
            Classes = string.IsNullOrWhiteSpace(dto.Classes) ? "G6-G10" : dto.Classes,
        }, ct);
    }

    public async Task<long> AddPaperAsync(SaveExamPaperDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Subject)) throw new ValidationException("Subject is required.");
        if (await _repo.PaperSubjectExistsAsync(dto.ExamId, dto.Subject.Trim(), ct))
            throw new ValidationException($"{dto.Subject} is already scheduled for this exam.");
        return await _repo.AddPaperAsync(new ExamPaper
        {
            ExamId = dto.ExamId, ClassLabel = dto.ClassLabel, Subject = dto.Subject.Trim(),
            ExamDate = dto.ExamDate, TimeLabel = dto.Time, Room = dto.Room, FullMarks = dto.FullMarks,
        }, ct);
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
        var rows = await _repo.GetInvoicesAsync(_school.SchoolId, status, ct);
        return rows.Select(ToDto).ToList();
    }

    public async Task<FeeSummaryDto> SummaryAsync(CancellationToken ct = default)
    {
        var all = await _repo.GetInvoicesAsync(_school.SchoolId, null, ct);
        var billed = all.Sum(i => i.Amount);
        var collected = all.Sum(i => i.Paid);
        return new FeeSummaryDto(billed, collected, billed - collected,
            all.Count(i => i.Status is "unpaid" or "partial"), all.Count(i => i.Status == "overdue"));
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

    public async Task<int> GenerateAsync(GenerateInvoicesDto dto, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(dto.Month)) throw new ValidationException("Billing month is required.");
        return await _repo.GenerateAsync(_school.SchoolId, dto.Month.Trim(), dto.DueDate, dto.ClassName, ct);
    }

    private static FeeInvoiceDto ToDto(FeeInvoiceRow i) => new(
        i.Id, i.InvoiceNo, i.StudentName, i.ClassLabel, i.Month, i.Amount, i.Paid, i.Amount - i.Paid, i.DueDate, i.Status);
}
