using System.Data;

namespace SchoolErp.Infrastructure.Persistence;

/// <summary>Creates open ADO.NET connections to MySQL.</summary>
public interface IDbConnectionFactory
{
    Task<IDbConnection> CreateOpenConnectionAsync(CancellationToken ct = default);
}
