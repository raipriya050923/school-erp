using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly IDbConnectionFactory _factory;
    public UserRepository(IDbConnectionFactory factory) => _factory = factory;

    private const string Cols = "id, school_id, user_type, username, email, phone, password_hash, full_name, is_active, must_change_password, password_changed_at";

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

    public async Task UpdatePasswordAsync(long userId, string passwordHash, bool mustChange = false, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        // password_changed_at records only the holder choosing their own; an administrator
        // issuing one leaves it untouched, so it still reads as never personally set.
        await DbHelper.ExecuteAsync(conn, @"
            UPDATE users
            SET password_hash=@h,
                must_change_password=@must,
                password_changed_at = IF(@must, password_changed_at, NOW()),
                updated_at=NOW()
            WHERE id=@id", ct,
            ("@h", passwordHash), ("@must", mustChange), ("@id", userId));
    }

    public async Task<bool> UsernameExistsAsync(string username, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.ScalarLongAsync(conn,
            "SELECT COUNT(*) FROM users WHERE username=@u AND deleted_at IS NULL", ct,
            ("@u", username)) > 0;
    }

    public async Task<long> CreateAsync(User user, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            INSERT INTO users
              (school_id, user_type, username, email, phone, password_hash, full_name, is_active,
               must_change_password, created_at, updated_at)
            VALUES
              (@school, @type, @username, @email, @phone, @hash, @name, @active, @must, NOW(), NOW());";
        return await DbHelper.InsertAsync(conn, sql, ct,
            ("@school", user.SchoolId), ("@type", user.UserType), ("@username", user.Username),
            ("@email", user.Email), ("@phone", user.Phone), ("@hash", user.PasswordHash),
            ("@name", user.FullName), ("@active", user.IsActive),
            ("@must", user.MustChangePassword));
    }

    public async Task<User?> GetByIdAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            $"SELECT {Cols} FROM users WHERE id=@id AND deleted_at IS NULL", Map, ct, ("@id", id));
    }

    public async Task<User?> GetSchoolAdminAsync(long schoolId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = $@"SELECT {Cols} FROM users
                     WHERE school_id=@sid AND user_type='school_admin' AND deleted_at IS NULL
                     ORDER BY id LIMIT 1";
        return await DbHelper.QuerySingleAsync(conn, sql, Map, ct, ("@sid", schoolId));
    }

    public async Task<long?> GetStaffIdAsync(long userId, CancellationToken ct = default)
        => await LinkedIdAsync("staff", userId, ct);

    public async Task<long?> GetStudentIdAsync(long userId, CancellationToken ct = default)
        => await LinkedIdAsync("students", userId, ct);

    public async Task<long?> GetChildStudentIdAsync(long parentUserId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        const string sql = @"
            SELECT sg.student_id
            FROM guardians g
            JOIN student_guardians sg ON sg.guardian_id = g.id
            JOIN students st ON st.id = sg.student_id AND st.deleted_at IS NULL
            WHERE g.user_id = @uid
            ORDER BY sg.student_id
            LIMIT 1";
        var id = await DbHelper.ScalarLongAsync(conn, sql, ct, ("@uid", parentUserId));
        return id == 0 ? null : id;
    }

    /// <summary>`table` is a compile-time literal from the two callers above — never user input.</summary>
    private async Task<long?> LinkedIdAsync(string table, long userId, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var id = await DbHelper.ScalarLongAsync(conn,
            $"SELECT id FROM {table} WHERE user_id=@uid AND deleted_at IS NULL ORDER BY id LIMIT 1", ct,
            ("@uid", userId));
        return id == 0 ? null : id;
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
        MustChangePassword = r.GetBool("must_change_password"),
        PasswordChangedAt = r.GetDateOrNull("password_changed_at"),
    };
}
