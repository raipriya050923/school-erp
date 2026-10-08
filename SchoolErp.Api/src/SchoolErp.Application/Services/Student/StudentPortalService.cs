using System.Globalization;
using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Student;
using SchoolErp.Application.DTOs.Billing;
using SchoolErp.Application.Services;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services.StudentPortal;

public class StudentPortalService : IStudentPortalService
{
    private readonly IStudentPortalRepository _repo;
    private readonly ITimetableRepository _timetable;
    private readonly ISchoolRepository _schools;
    private readonly IFeeSubmissionRepository _submissions;
    private readonly IFeeRepository _fees;
    private readonly FeeReceiptBuilder _receipts;
    private readonly INotificationCenter _bell;
    private readonly ICurrentUser _user;
    private readonly ICurrentStudent _me;

    public StudentPortalService(IStudentPortalRepository repo, ITimetableRepository timetable,
        ISchoolRepository schools, IFeeSubmissionRepository submissions, IFeeRepository fees,
        FeeReceiptBuilder receipts, INotificationCenter bell,
        ICurrentUser user, ICurrentStudent me)
    {
        _fees = fees;
        _receipts = receipts;
        _repo = repo;
        _timetable = timetable;
        _schools = schools;
        _submissions = submissions;
        _bell = bell;
        _user = user;
        _me = me;
    }

    /// <summary>Ways a school will accept money. Anything else is a typo, not a new channel.</summary>
    private static readonly HashSet<string> PaymentMethods = new(StringComparer.OrdinalIgnoreCase)
    {
        "upi", "bank_transfer", "cash", "cheque", "card", "esewa", "khalti", "online", "other",
    };

    private async Task<Student> ProfileOrThrow(CancellationToken ct)
        => await _repo.GetProfileAsync(_me.SchoolId, _me.StudentId, ct)
           ?? throw new NotFoundException("Student not found.");

    public async Task<StudentProfileDto?> GetProfileAsync(CancellationToken ct = default)
    {
        var s = await _repo.GetProfileAsync(_me.SchoolId, _me.StudentId, ct);
        return s is null ? null : new StudentProfileDto(s.Id, s.AdmissionNo, $"{s.FirstName} {s.LastName}".Trim(), s.ClassName, s.SectionName, s.RollNo);
    }

    public async Task<StudentAttendanceDto> GetAttendanceAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetAttendanceAsync(_me.SchoolId, _me.StudentId, ct);
        var work = rows.Where(r => r.Status != "holiday").ToList();
        int present = work.Count(r => r.Status == "present");
        int late = work.Count(r => r.Status == "late");
        int absent = work.Count(r => r.Status == "absent");
        int totalDays = work.Count;
        int overall = totalDays == 0 ? 0 : (int)Math.Round((present + late) / (double)totalDays * 100);

        var months = work
            .GroupBy(r => new DateTime(r.AttendanceDate.Year, r.AttendanceDate.Month, 1))
            .OrderBy(g => g.Key)
            .Select(g =>
            {
                var p = g.Count(x => x.Status == "present");
                var l = g.Count(x => x.Status == "late");
                var a = g.Count(x => x.Status == "absent");
                var pct = g.Count() == 0 ? 0 : (int)Math.Round((p + l) / (double)g.Count() * 100);
                return new AttendanceMonthDto(g.Key.ToString("MMMM yyyy", CultureInfo.InvariantCulture), p, a, l, pct);
            }).ToList();

        var recent = rows.OrderByDescending(r => r.AttendanceDate).Take(8)
            .Select(r => new AttendanceRecentDto(
                r.AttendanceDate.ToString("yyyy-MM-dd"),
                r.AttendanceDate.DayOfWeek.ToString(),
                Cap(r.Status))).ToList();

        return new StudentAttendanceDto(overall, present, totalDays, months, recent);
    }

    public async Task<StudentTimetableDto> GetTimetableAsync(CancellationToken ct = default)
    {
        var me = await ProfileOrThrow(ct);
        var slots = await _repo.GetTimetableAsync(_me.SchoolId, me.ClassName ?? "", me.SectionName ?? "", ct);

        // Columns come from the school's own period list. period_no counts breaks, so the fixed
        // 1..6 grid the page used to draw put a blank column where the break is, mislabelled
        // every period after it, and left the last period of the day off the table entirely.
        var periods = await _timetable.GetPeriodsAsync(_me.SchoolId, ct);
        if (periods.Count == 0)
        {
            await _timetable.SeedDefaultPeriodsAsync(_me.SchoolId, ct);
            periods = await _timetable.GetPeriodsAsync(_me.SchoolId, ct);
        }

        var school = await _schools.GetByIdAsync(_me.SchoolId, ct);
        var working = (school?.WorkingDays ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(d => int.TryParse(d, out var n) ? n : 0)
            .Where(n => n is >= 1 and <= 7)
            .Distinct().OrderBy(n => n).ToList();
        // A school that has not chosen its week still needs one to draw.
        if (working.Count == 0) working = new List<int> { 1, 2, 3, 4, 5, 6 };

        return new StudentTimetableDto(
            me.ClassName, me.SectionName,
            periods.Select((x, i) => new StudentTimetablePeriodDto(
                i + 1, x.Name, $"{x.StartTime:hh\\:mm}–{x.EndTime:hh\\:mm}", x.IsBreak)).ToList(),
            working,
            slots.Select(x => new StudentTimetableSlotDto(x.DayOfWeek, x.PeriodNo, x.TimeLabel, x.Subject, x.Room)).ToList());
    }

    public async Task<IReadOnlyList<StudentHomeworkDto>> GetHomeworkAsync(CancellationToken ct = default)
    {
        var me = await ProfileOrThrow(ct);
        var label = $"{me.ClassName}-{me.SectionName}";
        var rows = await _repo.GetHomeworkAsync(_me.SchoolId, me.ClassName ?? "", label, ct);
        return rows.Select(h => new StudentHomeworkDto(h.Title, h.Subject, h.DueDate, StudentHwStatus(h))).ToList();
    }

    public async Task<StudentExamsDto> GetExamsAsync(CancellationToken ct = default)
    {
        var me = await ProfileOrThrow(ct);
        var exam = await _repo.GetPublishedExamAsync(_me.SchoolId, ct);
        var results = new List<StudentResultDto>();
        decimal total = 0, fullTotal = 0;
        string? examName = exam?.Name;
        if (exam is not null)
        {
            var marks = await _repo.GetMarksAsync(_me.SchoolId, _me.StudentId, exam.Id, ct);
            foreach (var m in marks)
            {
                results.Add(new StudentResultDto(m.Subject, m.FullMarks, m.Marks, Grade(m.Marks, m.FullMarks)));
                total += m.Marks ?? 0;
                fullTotal += m.FullMarks;
            }
        }
        var pct = fullTotal == 0 ? 0 : (int)Math.Round(total / fullTotal * 100);

        var papers = await _repo.GetUpcomingPapersAsync(_me.SchoolId, me.ClassName ?? "", ct);
        var upcoming = papers.Select(p => new UpcomingPaperDto(p.ExamDate, p.Subject, p.TimeLabel, p.Room)).ToList();

        return new StudentExamsDto(examName, total, fullTotal, pct, Grade(total, fullTotal == 0 ? 1 : fullTotal), results, upcoming);
    }

    public async Task<IReadOnlyList<FeePaymentDto>> GetInvoicePaymentsAsync(long invoiceId, CancellationToken ct = default)
    {
        // The invoice has to be one of this student's before any payment on it is listed.
        var mine = await _repo.GetFeesAsync(_me.SchoolId, _me.StudentId, ct);
        if (mine.All(f => f.Id != invoiceId)) return Array.Empty<FeePaymentDto>();

        var rows = await _fees.GetPaymentsAsync(_me.SchoolId, invoiceId, ct);
        return rows.Select(p => new FeePaymentDto(
            p.Id, $"RCPT-{(p.PaidDate ?? p.CreatedAt):yy}-{p.Id:D5}",
            p.Amount, p.Method, p.Reference, p.PaidDate,
            Math.Max(0m, p.InvoiceTotal - p.PaidToDate))).ToList();
    }

    public Task<FeeReceiptDto?> GetReceiptAsync(long paymentId, CancellationToken ct = default)
        => _receipts.BuildAsync(_me.SchoolId, paymentId, _me.StudentId, ct);

    public async Task<IReadOnlyList<StudentFeeDto>> GetFeesAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetFeesAsync(_me.SchoolId, _me.StudentId, ct);
        // One query for every waiting claim rather than one per invoice — a year's worth of
        // months would otherwise be a round trip each.
        var pending = (await _submissions.PendingInvoiceIdsAsync(_me.SchoolId, _me.StudentId, ct)).ToHashSet();
        return rows.Select(i => new StudentFeeDto(
            i.Id, i.InvoiceNo, i.Month, i.Amount, i.Paid, i.Amount - i.Paid, i.DueDate, i.Status,
            pending.Contains(i.Id))).ToList();
    }

    /// <summary>
    /// Queues a payment the family says they have made. Deliberately writes nothing to the
    /// invoice: until somebody at the school matches it against a statement it is a claim, and
    /// an invoice that settles itself on the payer's say-so is not a fee system.
    /// </summary>
    public async Task<long> SubmitFeePaymentAsync(long invoiceId, SubmitFeePaymentDto dto,
        CancellationToken ct = default)
    {
        // Read through the student's own invoices, so an id belonging to another family
        // resolves to nothing rather than to somebody else's bill.
        var invoices = await _repo.GetFeesAsync(_me.SchoolId, _me.StudentId, ct);
        var invoice = invoices.FirstOrDefault(i => i.Id == invoiceId)
                      ?? throw new NotFoundException("That invoice is not on your account.");

        var balance = invoice.Amount - invoice.Paid;
        if (invoice.Status == "paid" || balance <= 0)
            throw new ValidationException("That invoice is already settled.");
        if (await _submissions.HasPendingForInvoiceAsync(_me.SchoolId, invoiceId, ct))
            throw new ValidationException(
                "A payment for this invoice is already waiting to be confirmed by the school.");

        if (dto.Amount <= 0) throw new ValidationException("Enter the amount you paid.");
        if (dto.Amount > balance)
            throw new ValidationException($"That is more than the {balance:0.##} still owing on this invoice.");

        var method = (dto.Method ?? string.Empty).Trim().ToLowerInvariant();
        if (!PaymentMethods.Contains(method))
            throw new ValidationException("Choose how you paid.");

        // A date in the future cannot have happened, and one from last year is almost always a
        // mistyped year — either way the office cannot match it to a statement.
        var paidDate = (dto.PaidDate ?? DateTime.UtcNow).Date;
        if (paidDate > DateTime.UtcNow.Date)
            throw new ValidationException("The payment date cannot be in the future.");
        if (paidDate < DateTime.UtcNow.Date.AddMonths(-12))
            throw new ValidationException("The payment date looks too far back — check the year.");

        // Cash handed over at the office has no reference to quote; anything that moved
        // electronically does, and without it there is nothing to match.
        var reference = string.IsNullOrWhiteSpace(dto.Reference) ? null : dto.Reference.Trim();
        if (reference is null && method is not ("cash" or "other"))
            throw new ValidationException("Enter the transaction or reference number.");

        var id = await _submissions.CreateAsync(new FeePaymentSubmission
        {
            SchoolId = _me.SchoolId,
            InvoiceId = invoiceId,
            StudentId = _me.StudentId,
            Amount = dto.Amount,
            Method = method,
            Reference = reference,
            PaidDate = paidDate,
            Note = string.IsNullOrWhiteSpace(dto.Note) ? null : dto.Note.Trim(),
            SubmittedBy = _user.UserId,
        }, ct);

        var me = await ProfileOrThrow(ct);
        await _bell.NotifyRoleAsync(_me.SchoolId, "school_admin",
            "Fee payment to confirm",
            $"{me.FirstName} {me.LastName} submitted {dto.Amount:0.##} for {invoice.Month ?? invoice.InvoiceNo} via {method}.",
            "fee", "fee_payment_submission", id, ct);

        return id;
    }

    public async Task<IReadOnlyList<StudentFeeSubmissionDto>> GetFeeSubmissionsAsync(CancellationToken ct = default)
    {
        var rows = await _submissions.GetForStudentAsync(_me.SchoolId, _me.StudentId, ct);
        return rows.Select(r => new StudentFeeSubmissionDto(
            r.Id, r.InvoiceId, r.InvoiceNo, r.Month, r.Amount, r.Method, r.Reference, r.PaidDate,
            r.Status, r.CreatedAt, r.ReviewedAt, r.ReviewNote)).ToList();
    }

    public async Task<IReadOnlyList<StudentNoticeDto>> GetNoticesAsync(CancellationToken ct = default)
    {
        var rows = await _repo.GetNoticesAsync(_me.SchoolId, ct);
        return rows.Select(n => new StudentNoticeDto(n.Id, n.Title, n.Body, n.Audience, n.PublishDate)).ToList();
    }

    public async Task<StudentDashboardDto> GetDashboardAsync(CancellationToken ct = default)
    {
        var me = await ProfileOrThrow(ct);
        var att = await GetAttendanceAsync(ct);
        var hw = await GetHomeworkAsync(ct);
        var pending = hw.Where(h => h.Status == "Pending").ToList();
        var papers = await _repo.GetUpcomingPapersAsync(_me.SchoolId, me.ClassName ?? "", ct);
        var next = papers.OrderBy(p => p.ExamDate).FirstOrDefault();
        var fees = await _repo.GetFeesAsync(_me.SchoolId, _me.StudentId, ct);
        var feeDue = fees.Sum(f => f.Amount - f.Paid);

        return new StudentDashboardDto(
            $"{me.FirstName} {me.LastName}".Trim(), me.ClassName, me.SectionName, me.RollNo,
            att.OverallPercent, att.PresentDays, att.TotalDays,
            pending.Count, next?.Subject, next?.ExamDate, feeDue,
            pending.Take(3).ToList());
    }

    private static string StudentHwStatus(TeacherHomework h)
        => h.DueDate.HasValue && h.DueDate.Value.Date < DateTime.UtcNow.Date ? "Closed" : "Pending";

    private static string Grade(decimal? marks, decimal full)
    {
        if (marks is null || full == 0) return "—";
        var pct = (double)(marks.Value / full) * 100;
        return pct switch
        {
            >= 90 => "A+", >= 80 => "A", >= 70 => "B+", >= 60 => "B",
            >= 50 => "C+", >= 40 => "C", _ => "NG",
        };
    }

    private static string Cap(string s) => string.IsNullOrEmpty(s) ? s : char.ToUpper(s[0]) + s[1..];
}
