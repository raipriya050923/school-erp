namespace SchoolErp.Domain.Entities;

/// <summary>
/// A parent or guardian of one or more students. Carries an optional login: a
/// guardian can be recorded as a contact long before anyone issues them an
/// account, which is why <see cref="UserId"/> is nullable.
/// </summary>
public class Guardian
{
    public long Id { get; set; }
    public long SchoolId { get; set; }
    public long? UserId { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    /// <summary>father | mother | guardian | other</summary>
    public string Relation { get; set; } = "guardian";
    public string? Email { get; set; }
    public string Phone { get; set; } = string.Empty;
    public string? Occupation { get; set; }
    public string? Address { get; set; }

    /// <summary>The login username, when the guardian has an account.</summary>
    public string? Username { get; set; }

    public string FullName => $"{FirstName} {LastName}".Trim();
}
