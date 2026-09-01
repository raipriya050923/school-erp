namespace SchoolErp.Application.DTOs.Admin;

/* -------- staff attendance -------- */

public record StaffAttendanceRowDto(long StaffId, string? EmployeeCode, string Name, string Status, string? Remarks);

public record StaffAttendanceSummaryDto(int Present, int Absent, int Late, int HalfDay, int OnLeave);

public class SaveStaffAttendanceDto
{
    public DateTime Date { get; set; }
    public List<StaffAttendanceEntryDto> Entries { get; set; } = new();
}
public class StaffAttendanceEntryDto
{
    public long StaffId { get; set; }
    public string Status { get; set; } = "present";
    public string? Remarks { get; set; }
}

/* -------- leave -------- */

public record LeaveTypeDto(long Id, string Name, bool IsPaid, int? MaxDaysPerYear);

public record LeaveApplicationDto(
    long Id, long LeaveTypeId, string? LeaveTypeName, string? ApplicantName,
    DateTime FromDate, DateTime ToDate, decimal Days, string Reason,
    string Status, string? ReviewedByName, DateTime? ReviewedAt, string? ReviewRemarks,
    DateTime CreatedAt);

public class ApplyLeaveDto
{
    public long LeaveTypeId { get; set; }
    public DateTime FromDate { get; set; }
    public DateTime ToDate { get; set; }
    public string Reason { get; set; } = string.Empty;
}

/// <summary>An admin recording leave for a staff member who phoned in rather than applied.</summary>
public class ApplyLeaveForStaffDto : ApplyLeaveDto
{
    public long StaffId { get; set; }
    /// <summary>Approve immediately — an admin recording an accepted absence needs no second step.</summary>
    public bool AutoApprove { get; set; } = true;
}

public class SaveLeaveTypeDto
{
    public string Name { get; set; } = string.Empty;
    public bool IsPaid { get; set; } = true;
    public int? MaxDaysPerYear { get; set; }
}

/// <summary>Status must be "approved" or "rejected".</summary>
public record ReviewLeaveDto(string Status, string? Remarks);
