using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IUserRepository
{
    Task<User?> GetByUsernameOrEmailAsync(string usernameOrEmail, CancellationToken ct = default);
    Task<User?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task<User?> GetByIdAsync(long id, CancellationToken ct = default);
    /// <summary>
    /// Writes a new password. <paramref name="mustChange"/> distinguishes the holder choosing
    /// their own (false — the flag clears) from an administrator issuing one (true).
    /// </summary>
    Task UpdatePasswordAsync(long userId, string passwordHash, bool mustChange = false, CancellationToken ct = default);

    /// <summary>Login looks users up across all tenants, so usernames must be globally unique.</summary>
    Task<bool> UsernameExistsAsync(string username, CancellationToken ct = default);
    Task<long> CreateAsync(User user, CancellationToken ct = default);

    /// <summary>The school's administrator login, or null if it has none.</summary>
    Task<User?> GetSchoolAdminAsync(long schoolId, CancellationToken ct = default);

    /// <summary>The staff row this login belongs to, or null when the account has no staff record.</summary>
    Task<long?> GetStaffIdAsync(long userId, CancellationToken ct = default);
    /// <summary>The student row this login belongs to, or null when the account has no student record.</summary>
    Task<long?> GetStudentIdAsync(long userId, CancellationToken ct = default);

    /// <summary>
    /// The student a parent login is attached to, via guardians -> student_guardians.
    /// A parent with several children resolves to the eldest record for now; the
    /// portal shows one child at a time and has no child switcher yet.
    /// </summary>
    Task<long?> GetChildStudentIdAsync(long parentUserId, CancellationToken ct = default);

    Task CreateResetTokenAsync(long userId, string token, DateTime expiresAt, CancellationToken ct = default);
    Task<(long userId, DateTime expiresAt, bool used)?> GetResetTokenAsync(string token, CancellationToken ct = default);
    Task MarkResetTokenUsedAsync(string token, CancellationToken ct = default);
}
