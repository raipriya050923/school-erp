namespace SchoolErp.Domain.Entities;

/// <summary>A staff member / teacher. Maps to the `staff` table.</summary>
public class StaffMember
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long? UserId { get; set; }
    public string EmployeeCode { get; set; } = string.Empty;
    public string StaffType { get; set; } = "teacher";
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Gender { get; set; }
    public DateTime? Dob { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Pincode { get; set; }

    // Geography master (platform-level). Country is not stored here — it follows the school.
    public long? StateId { get; set; }
    public long? CityId { get; set; }
    public string? Qualification { get; set; }
    public string? Specialization { get; set; }   // subject taught
    public DateTime? JoiningDate { get; set; }
    public string Status { get; set; } = "active"; // active | on_leave | resigned | terminated | inactive
    public DateTime CreatedAt { get; set; }
}

/// <summary>
/// One qualification a staff member holds. Maps to `staff_qualifications`.
/// <see cref="Institution"/> and <see cref="CompletionYear"/> are optional: rows predate them,
/// and an admin should not be blocked on remembering a year to record a degree.
/// </summary>
public class StaffQualification
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    /// <summary>Awarding university or board.</summary>
    public string? Institution { get; set; }
    public int? CompletionYear { get; set; }
}
