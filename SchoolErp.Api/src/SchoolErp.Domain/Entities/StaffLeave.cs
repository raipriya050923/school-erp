namespace SchoolErp.Domain.Entities;

/// <summary>One staff member's attendance for one day. Maps to `staff_attendance`.</summary>
public class StaffAttendance
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long StaffId { get; set; }
    public DateTime AttendanceDate { get; set; }
    public string Status { get; set; } = "present";   // present | absent | late | half_day | on_leave
    public string? Remarks { get; set; }

    // Joined for display — not columns.
    public string? StaffName { get; set; }
    public string? EmployeeCode { get; set; }
}

/// <summary>A category of leave a school offers. Maps to `leave_types`.</summary>
public class LeaveType
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string ApplicableTo { get; set; } = "both";   // staff | student | both
    public int? MaxDaysPerYear { get; set; }
    public bool IsPaid { get; set; } = true;
}

/// <summary>A leave request and its review. Maps to `leave_applications`.</summary>
public class LeaveApplication
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long LeaveTypeId { get; set; }
    public long ApplicantUserId { get; set; }
    public DateTime FromDate { get; set; }
    public DateTime ToDate { get; set; }
    public decimal Days { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string Status { get; set; } = "pending";   // pending | approved | rejected | cancelled
    public long? ReviewedBy { get; set; }
    public DateTime? ReviewedAt { get; set; }
    public string? ReviewRemarks { get; set; }
    public DateTime CreatedAt { get; set; }

    // Joined for display — not columns.
    public string? LeaveTypeName { get; set; }
    public string? ApplicantName { get; set; }
    public string? ReviewedByName { get; set; }
}
