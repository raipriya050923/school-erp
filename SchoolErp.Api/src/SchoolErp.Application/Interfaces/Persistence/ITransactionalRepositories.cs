using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IAttendanceRepository
{
    Task<IReadOnlyList<DailyAttendance>> GetSectionAsync(long schoolId, string className, string sectionName, DateTime date, CancellationToken ct = default);
    Task UpsertAsync(long schoolId, string className, string sectionName, DateTime date, IEnumerable<(long studentId, string status)> entries, CancellationToken ct = default);
    Task<IReadOnlyList<DailyAttendance>> GetStudentRangeAsync(long schoolId, long studentId, DateTime from, DateTime to, CancellationToken ct = default);
    /// <summary>
    /// School-wide present/total for the most recent <paramref name="days"/> days that have any
    /// marked attendance, oldest first. Counts marked days rather than calendar days so holidays
    /// and gaps in marking do not empty the dashboard chart.
    /// </summary>
    Task<IReadOnlyList<(DateTime Date, int Present, int Total)>> GetDailyRatesAsync(long schoolId, int days, CancellationToken ct = default);
}

public interface IExamRepository
{
    Task<IReadOnlyList<Exam>> GetAllWithPapersAsync(long schoolId, CancellationToken ct = default);
    Task<Exam?> GetAsync(long schoolId, long examId, CancellationToken ct = default);
    Task SetStatusAsync(long schoolId, long examId, string status, CancellationToken ct = default);
    Task<long> CreateExamAsync(Exam e, CancellationToken ct = default);
    Task UpdateExamAsync(Exam e, CancellationToken ct = default);
    /// <summary>Removes the exam together with its papers and any marks recorded against it.</summary>
    Task DeleteExamAsync(long schoolId, long examId, CancellationToken ct = default);
    Task<long> AddPaperAsync(ExamPaper p, CancellationToken ct = default);
    Task DeletePaperAsync(long schoolId, long paperId, CancellationToken ct = default);
    /// <summary>
    /// Whether this exam already schedules the subject <em>for that class</em>. An exam covering
    /// several classes needs the same subject once per class, so the check cannot be exam-wide.
    /// </summary>
    Task<bool> PaperSubjectExistsAsync(long examId, string? classLabel, string subject, CancellationToken ct = default);
    Task<IReadOnlyList<StudentMark>> GetMarksAsync(long schoolId, long examId, string className, string sectionName, string subject, CancellationToken ct = default);
    /// <summary>
    /// Writes marks for students of one section. The class and section are part of the write, not
    /// just the read: entries name student ids, and without them any id could be marked.
    /// Returns the number of entries that matched a student and were applied.
    /// </summary>
    Task<int> UpsertMarksAsync(long schoolId, long examId, string className, string sectionName, string subject, int fullMarks, IEnumerable<(long studentId, decimal? marks)> entries, CancellationToken ct = default);
    /// <summary>
    /// The whole section's marks for one exam, one row per student per recorded subject. Students
    /// with nothing recorded still appear, with an empty subject, so the grid can show every row.
    /// </summary>
    Task<IReadOnlyList<StudentMark>> GetSectionMarksAsync(long schoolId, long examId, string className, string sectionName, CancellationToken ct = default);
    /// <summary>Every paper of an exam that applies to a class, with how many marks are in.</summary>
    Task<IReadOnlyList<MarksProgressRow>> GetMarksProgressAsync(long schoolId, long examId, string className, string sectionName, CancellationToken ct = default);
}

public interface ITimetableRepository
{
    Task<IReadOnlyList<TimetableSlot>> GetByTeacherAsync(long schoolId, long staffId, CancellationToken ct = default);

    /// <summary>The school's period columns, breaks included, in running order.</summary>
    Task<IReadOnlyList<TimetablePeriod>> GetPeriodsAsync(long schoolId, CancellationToken ct = default);
    Task SeedDefaultPeriodsAsync(long schoolId, CancellationToken ct = default);

    Task<TimetablePeriod?> GetPeriodAsync(long schoolId, long id, CancellationToken ct = default);
    Task<long> InsertPeriodAsync(TimetablePeriod period, CancellationToken ct = default);
    Task UpdatePeriodAsync(TimetablePeriod period, CancellationToken ct = default);
    Task DeletePeriodAsync(long schoolId, long id, CancellationToken ct = default);
    /// <summary>Rewrites sort_order so it matches the periods' chronological order.</summary>
    Task SetPeriodSortOrderAsync(long schoolId, long id, int sortOrder, CancellationToken ct = default);

    /* Slots are keyed on period_no — the period's running position, not its id — so adding,
       moving or removing a period has to renumber the cells that sit after it, or the grid
       silently shifts every subject into the wrong column. */

    /// <summary>How many cells school-wide sit in one period position.</summary>
    Task<int> CountSlotsAtPeriodAsync(long schoolId, int periodNo, CancellationToken ct = default);
    /// <summary>Makes room at <paramref name="at"/>: everything from there on moves one later.</summary>
    Task OpenSlotGapAsync(long schoolId, int at, CancellationToken ct = default);
    /// <summary>Closes the hole left at <paramref name="at"/>: everything after it moves one earlier.</summary>
    Task CloseSlotGapAsync(long schoolId, int at, CancellationToken ct = default);
    /// <summary>Moves one position's cells to another, sliding everything in between.</summary>
    Task MoveSlotPeriodAsync(long schoolId, int from, int to, CancellationToken ct = default);
    /// <summary>Re-stamps the denormalised time label on a position's cells after its clock changes.</summary>
    Task SetSlotTimeLabelAsync(long schoolId, int periodNo, string timeLabel, CancellationToken ct = default);

    /// <summary>Every filled cell for one section.</summary>
    Task<IReadOnlyList<TimetableSlot>> GetForSectionAsync(long schoolId, string className, string sectionName, CancellationToken ct = default);
    Task UpsertSlotAsync(TimetableSlot slot, CancellationToken ct = default);
    Task ClearSlotAsync(long schoolId, string className, string sectionName, int day, int period, CancellationToken ct = default);

    /// <summary>
    /// Empties the grid school-wide — one day, or the whole week when no day is given. Returns
    /// how many cells went, since "nothing happened" and "cleared 42" look the same otherwise.
    /// </summary>
    Task<int> ClearSlotsAsync(long schoolId, int? dayOfWeek, CancellationToken ct = default);

    /// <summary>How many periods are scheduled school-wide on one day.</summary>
    Task<int> CountSlotsOnDayAsync(long schoolId, int dayOfWeek, CancellationToken ct = default);
    /// <summary>Periods already timetabled for one subject in one section.</summary>
    Task<IReadOnlyList<TimetableSlot>> GetForSectionSubjectAsync(long schoolId, string className,
        string sectionName, string subject, CancellationToken ct = default);
    /// <summary>
    /// Repoints those periods at a new teacher (or none). Keeps the timetable honest when the
    /// subject-teacher assignment changes — otherwise the grid keeps naming whoever taught it before.
    /// </summary>
    Task<int> RetargetSlotTeacherAsync(long schoolId, string className, string sectionName,
        string subject, long? staffId, CancellationToken ct = default);

    /// <summary>
    /// Where else this teacher is already booked in the same period — a teacher cannot be in two
    /// rooms at once, and the cell being edited is excluded so re-saving it is not a clash.
    /// </summary>
    Task<TimetableSlot?> FindTeacherClashAsync(long schoolId, long staffId, int day, int period,
        string className, string sectionName, CancellationToken ct = default);
    /// <summary>Same idea for the room, when one is named.</summary>
    Task<TimetableSlot?> FindRoomClashAsync(long schoolId, string room, int day, int period,
        string className, string sectionName, CancellationToken ct = default);
}

public interface IFeeRepository
{
    Task<IReadOnlyList<FeeInvoiceRow>> GetInvoicesAsync(long schoolId, string? status, CancellationToken ct = default);
    Task<FeeInvoiceRow?> GetInvoiceAsync(long schoolId, long id, CancellationToken ct = default);
    /// <summary>What the invoice total was made up of, so the amount can be explained later.</summary>
    Task<IReadOnlyList<FeeInvoiceLine>> GetInvoiceLinesAsync(long schoolId, long invoiceId, CancellationToken ct = default);
    /// <summary>Every payment taken against one invoice, oldest first.</summary>
    Task<IReadOnlyList<FeePaymentRow>> GetPaymentsAsync(long schoolId, long invoiceId, CancellationToken ct = default);
    /// <summary>
    /// One payment with everything a receipt prints. Null when it belongs to another school, so
    /// the receipt endpoints need no tenant check of their own.
    /// </summary>
    Task<FeePaymentRow?> GetPaymentAsync(long schoolId, long paymentId, CancellationToken ct = default);
    /// <summary>Records money received and re-totals the invoice. Returns the new payment's id.</summary>
    Task<long> RecordPaymentAsync(long schoolId, long invoiceId, decimal amount, string method, string? reference, DateTime date, CancellationToken ct = default);
    /// <summary>
    /// Raises one invoice per unbilled active student, priced from the fee structure for the
    /// current academic year. <paramref name="includeOneOff"/> adds the yearly and one-time heads
    /// on top of the monthly ones, for the first run of a year.
    /// </summary>
    Task<FeeGenerationResult> GenerateAsync(long schoolId, string month, DateTime due, string className, bool includeOneOff, CancellationToken ct = default);
    /// <summary>
    /// Flags still-owing invoices whose due date has passed. Nothing runs on a schedule, so the
    /// read paths call this first — otherwise an invoice stays 'unpaid' forever past its due date.
    /// </summary>
    Task<int> MarkOverdueAsync(long schoolId, CancellationToken ct = default);
}

/// <summary>
/// Payments declared by students and parents, before the school has confirmed them. Kept apart
/// from <see cref="IFeeRepository"/> on purpose: nothing here contributes to an invoice's paid
/// total until a reviewer turns it into a real payment.
/// </summary>
public interface IFeeSubmissionRepository
{
    Task<long> CreateAsync(FeePaymentSubmission s, CancellationToken ct = default);
    Task<FeePaymentSubmission?> GetAsync(long schoolId, long id, CancellationToken ct = default);
    /// <summary>One student's own submissions, newest first.</summary>
    Task<IReadOnlyList<FeePaymentSubmission>> GetForStudentAsync(long schoolId, long studentId, CancellationToken ct = default);
    /// <summary>The review queue, with the student and invoice joined in. Null status returns all.</summary>
    Task<IReadOnlyList<FeePaymentSubmission>> ListAsync(long schoolId, string? status, CancellationToken ct = default);
    /// <summary>
    /// Whether this invoice already has a claim waiting. One at a time, so a parent who taps
    /// twice does not queue the same transfer for the office to verify twice.
    /// </summary>
    Task<bool> HasPendingForInvoiceAsync(long schoolId, long invoiceId, CancellationToken ct = default);
    /// <summary>How many of a student's submissions are still waiting, for the portal's own list.</summary>
    Task<IReadOnlyList<long>> PendingInvoiceIdsAsync(long schoolId, long studentId, CancellationToken ct = default);
    /// <summary>
    /// Claims a pending submission for a decision. Returns the number of rows it moved: 0 means
    /// another reviewer got there first, and the caller must not act on it.
    /// </summary>
    Task<int> MarkReviewedAsync(long schoolId, long id, string status, long reviewedBy, string? note,
        CancellationToken ct = default);
    /// <summary>Links a verified submission to the payment it became, once that exists.</summary>
    Task SetPaymentIdAsync(long schoolId, long id, long paymentId, CancellationToken ct = default);
}
