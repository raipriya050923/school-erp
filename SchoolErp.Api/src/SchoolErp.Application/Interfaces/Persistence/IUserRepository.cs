using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IUserRepository
{
    Task<User?> GetByUsernameOrEmailAsync(string usernameOrEmail, CancellationToken ct = default);
    Task<User?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task<User?> GetByIdAsync(long id, CancellationToken ct = default);
    Task UpdatePasswordAsync(long userId, string passwordHash, CancellationToken ct = default);

    /// <summary>Login looks users up across all tenants, so usernames must be globally unique.</summary>
    Task<bool> UsernameExistsAsync(string username, CancellationToken ct = default);
    Task<long> CreateAsync(User user, CancellationToken ct = default);

    /// <summary>The school's administrator login, or null if it has none.</summary>
    Task<User?> GetSchoolAdminAsync(long schoolId, CancellationToken ct = default);

    /// <summary>The staff row this login belongs to, or null when the account has no staff record.</summary>
    Task<long?> GetStaffIdAsync(long userId, CancellationToken ct = default);
    /// <summary>The student row this login belongs to, or null when the account has no student record.</summary>
    Task<long?> GetStudentIdAsync(long userId, CancellationToken ct = default);

    Task CreateResetTokenAsync(long userId, string token, DateTime expiresAt, CancellationToken ct = default);
    Task<(long userId, DateTime expiresAt, bool used)?> GetResetTokenAsync(string token, CancellationToken ct = default);
    Task MarkResetTokenUsedAsync(string token, CancellationToken ct = default);
}
