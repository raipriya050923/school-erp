using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Common;

/// <summary>
/// How an exam's status is decided, in one place so the admin console, the teacher portal and
/// the student portal cannot disagree about it.
///
/// Scheduled / ongoing / completed follow the exam's dates, so they are worked out on read
/// rather than stored — no nightly job, and the badge is never stale. Anything an admin
/// deliberately pins (cancelled, results published, or an early completion) is stored in
/// <c>exam.status</c> and wins. <see cref="Auto"/> is the stored value meaning "follow the dates".
/// </summary>
public static class ExamStatus
{
    public const string Auto = "auto";

    /// <summary>Statuses an admin may pin, plus <see cref="Auto"/> to hand control back.</summary>
    public static readonly string[] Settable =
        { Auto, "scheduled", "ongoing", "completed", "cancelled", "result_published" };

    /// <summary>What the dates alone say, ignoring any override.</summary>
    public static string FromDates(DateTime? startDate, DateTime? endDate)
    {
        var today = DateTime.UtcNow.Date;
        if (startDate is null || endDate is null) return "scheduled";
        if (today < startDate.Value.Date) return "scheduled";
        return today > endDate.Value.Date ? "completed" : "ongoing";
    }

    public static string FromDates(Exam e) => FromDates(e.StartDate, e.EndDate);

    /// <summary>The status every caller should act on: the pinned value, else the dates.</summary>
    public static string Effective(Exam e) =>
        string.IsNullOrWhiteSpace(e.Status) || e.Status == Auto ? FromDates(e) : e.Status;

    /// <summary>True when an admin pinned the status rather than letting the dates drive it.</summary>
    public static bool IsManual(Exam e) => !string.IsNullOrWhiteSpace(e.Status) && e.Status != Auto;
}
