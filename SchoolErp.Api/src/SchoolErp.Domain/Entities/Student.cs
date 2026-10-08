namespace SchoolErp.Domain.Entities;

/// <summary>A student. Maps to the `students` table (+ admin demo columns).</summary>
public class Student
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long? UserId { get; set; }
    public string AdmissionNo { get; set; } = string.Empty;
    public string? RollNo { get; set; }
    public string? ClassName { get; set; }
    public string? SectionName { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Gender { get; set; }
    public DateTime? Dob { get; set; }
    public string? BloodGroup { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? GuardianName { get; set; }
    public string? GuardianPhone { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Pincode { get; set; }

    // Geography master (platform-level). Country is not stored here — it follows the school.
    public long? StateId { get; set; }
    public long? CityId { get; set; }
    public string? PreviousSchool { get; set; }
    /// <summary>
    /// Transfer certificate number from the school the student left. Optional and not unique:
    /// it belongs to the issuing school's numbering, so two arrivals from different schools may
    /// legitimately share one, and a student admitted at nursery has none.
    /// </summary>
    public string? TcNo { get; set; }
    public DateTime? AdmissionDate { get; set; }
    public decimal FeeDue { get; set; }
    public string Status { get; set; } = "active";  // active | inactive | transferred | graduated | dropped
    public DateTime CreatedAt { get; set; }
}
