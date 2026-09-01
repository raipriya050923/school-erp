namespace SchoolErp.Application.Interfaces.Services;

/// <summary>
/// "Today" as the school experiences it. The server runs on UTC while schools do not, so a
/// UTC date rejects work the user considers same-day — in Kathmandu (UTC+5:45) every evening
/// after 18:15 local is already tomorrow by UTC.
/// </summary>
public interface ISchoolClock
{
    Task<DateTime> TodayAsync(CancellationToken ct = default);
}
