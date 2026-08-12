using System.Data;
using MySqlConnector;

namespace SchoolErp.Infrastructure.Persistence;

/// <summary>ADO.NET connection factory backed by MySqlConnector.</summary>
public class MySqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;

    public MySqlConnectionFactory(string connectionString)
        => _connectionString = connectionString;

    public async Task<IDbConnection> CreateOpenConnectionAsync(CancellationToken ct = default)
    {
        var conn = new MySqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        return conn;
    }
}
