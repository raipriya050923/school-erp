namespace SchoolErp.Domain.Entities;

/// <summary>A login account (any portal). Maps to the `users` table.</summary>
public class User
{
    public long Id { get; set; }
    public long? SchoolId { get; set; }
    public string UserType { get; set; } = string.Empty;   // super_admin | school_admin | teacher | student | parent | staff
    public string Username { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string PasswordHash { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}
