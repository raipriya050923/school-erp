using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services;

/// <inheritdoc />
public class SchoolClock : ISchoolClock
{
    private readonly ISchoolRepository _schools;
    private readonly ICurrentSchool _school;

    public SchoolClock(ISchoolRepository schools, ICurrentSchool school)
    {
        _schools = schools;
        _school = school;
    }

    public async Task<DateTime> TodayAsync(CancellationToken ct = default)
    {
        var school = await _schools.GetByIdAsync(_school.SchoolId, ct);
        return LocalNow(school?.Timezone).Date;
    }

    /// <summary>
    /// Fixed offsets for the zones this product serves, used only when the host cannot resolve
    /// the id itself. Neither observes daylight saving, so a constant offset is exact for them —
    /// this is a safety net for a host built without ICU, not a general timezone implementation.
    /// </summary>
    private static readonly Dictionary<string, TimeSpan> KnownOffsets = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Asia/Kathmandu"] = TimeSpan.FromMinutes(345),   // UTC+5:45
        ["Asia/Katmandu"]  = TimeSpan.FromMinutes(345),   // legacy spelling
        ["Asia/Kolkata"]   = TimeSpan.FromMinutes(330),   // UTC+5:30
        ["Asia/Calcutta"]  = TimeSpan.FromMinutes(330),
        ["Asia/Dhaka"]     = TimeSpan.FromHours(6),
        ["Asia/Thimphu"]   = TimeSpan.FromHours(6),
    };

    /// <summary>
    /// Converts to the school's zone. Falls back to a known offset, then to UTC, so a timezone
    /// the host cannot resolve never makes attendance unsavable.
    /// </summary>
    private static DateTime LocalNow(string? timezoneId)
    {
        var utc = DateTime.UtcNow;
        if (string.IsNullOrWhiteSpace(timezoneId)) return utc;
        try
        {
            var tz = TimeZoneInfo.FindSystemTimeZoneById(timezoneId);
            return TimeZoneInfo.ConvertTimeFromUtc(utc, tz);
        }
        catch (TimeZoneNotFoundException)
        {
            return KnownOffsets.TryGetValue(timezoneId.Trim(), out var offset) ? utc + offset : utc;
        }
        catch (InvalidTimeZoneException) { return utc; }
    }
}
