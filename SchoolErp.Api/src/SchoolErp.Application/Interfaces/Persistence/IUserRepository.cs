using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

public interface IUserRepository
{
    Task<User?> GetByUsernameOrEmailAsync(string usernameOrEmail, CancellationToken ct = default);
    Task<User?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task UpdatePasswordAsync(long userId, string passwordHash, CancellationToken ct = default);

    Task CreateResetTokenAsync(long userId, string token, DateTime expiresAt, CancellationToken ct = default);
    Task<(long userId, DateTime expiresAt, bool used)?> GetResetTokenAsync(string token, CancellationToken ct = default);
    Task MarkResetTokenUsedAsync(string token, CancellationToken ct = default);
}
