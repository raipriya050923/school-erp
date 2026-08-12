using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly IDbConnectionFactory _factory;
    public UserRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = "id, school_id, user_type, username, email, phone, password_hash, full_name, is_active";

    public async Task<User?> GetByUsernameOrEmailAsync(string usernameOrEmail, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM users WHERE (username=@v OR email=@v) AND deleted_at IS NULL ORDER BY id LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@v", usernameOrEmail));
    }

    public async Task<User?> GetByEmailAsync(string email, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $"SELECT {Cols} FROM users WHERE email=@e AND deleted_at IS NULL ORDER BY id LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@e", email));
    }

    public async Task UpdatePasswordAsync(long userId, string passwordHash, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE users SET password_hash=@h, updated_at=NOW() WHERE id=@id", ct,
            ("@h", passwordHash), ("@id", userId));
    }

    public async Task CreateResetTokenAsync(long userId, string token, DateTime expiresAt, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            @"INSERT INTO password_resets (user_id, token, channel, expires_at, created_at)
              VALUES (@uid, @tok, 'email', @exp, NOW())", ct,
            ("@uid", userId), ("@tok", token), ("@exp", expiresAt));
    }

    public async Task<(long userId, DateTime expiresAt, bool used)?> GetResetTokenAsync(string token, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = "SELECT user_id, expires_at, used_at FROM password_resets WHERE token=@tok ORDER BY id DESC LIMIT 1";
        return await DbHelper.QuerySingleAsync<Boxed>(conn, sql, r => new Boxed
        {
            UserId = r.GetLong("user_id"),
            ExpiresAt = r.GetDate("expires_at"),
            Used = !r.IsDBNull(r.GetOrdinal("used_at")),
        }, ct, ("@tok", token)) is { } b ? (b.UserId, b.ExpiresAt, b.Used) : null;
    }

    public async Task MarkResetTokenUsedAsync(string token, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE password_resets SET used_at=NOW() WHERE token=@tok", ct, ("@tok", token));
    }

    private sealed class Boxed { public long UserId; public DateTime ExpiresAt; public bool Used; }

    private static User Map(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        SchoolId = r.GetLongOrNull("school_id"),
        UserType = r.GetString("user_type"),
        Username = r.GetString("username"),
        Email = r.GetStringOrNull("email"),
        Phone = r.GetStringOrNull("phone"),
        PasswordHash = r.GetString("password_hash"),
        FullName = r.GetString("full_name"),
        IsActive = r.GetBool("is_active"),
    };
}
