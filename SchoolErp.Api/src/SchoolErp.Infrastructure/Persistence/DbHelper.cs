using System.Data;
using MySqlConnector;

namespace SchoolErp.Infrastructure.Persistence;

/// <summary>
/// Thin helpers over raw ADO.NET to reduce boilerplate in repositories.
/// All access uses parameterised MySqlCommand — no string concatenation of values.
/// </summary>
internal static class DbHelper
{
    public static MySqlCommand CreateCommand(IDbConnection conn, string sql, params (string name, object? value)[] ps)
    {
        var cmd = (MySqlCommand)conn.CreateCommand();
        cmd.CommandText = sql;
        foreach (var (name, value) in ps)
            cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return cmd;
    }

    public static async Task<List<T>> QueryAsync<T>(
        IDbConnection conn, string sql, Func<IDataRecord, T> map, CancellationToken ct,
        params (string name, object? value)[] ps)
    {
        await using var cmd = CreateCommand(conn, sql, ps);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        var list = new List<T>();
        while (await reader.ReadAsync(ct))
            list.Add(map(reader));
        return list;
    }

    public static async Task<T?> QuerySingleAsync<T>(
        IDbConnection conn, string sql, Func<IDataRecord, T> map, CancellationToken ct,
        params (string name, object? value)[] ps) where T : class
    {
        await using var cmd = CreateCommand(conn, sql, ps);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? map(reader) : null;
    }

    public static async Task<int> ExecuteAsync(
        IDbConnection conn, string sql, CancellationToken ct, params (string name, object? value)[] ps)
    {
        await using var cmd = CreateCommand(conn, sql, ps);
        return await cmd.ExecuteNonQueryAsync(ct);
    }

    public static async Task<long> InsertAsync(
        IDbConnection conn, string sql, CancellationToken ct, params (string name, object? value)[] ps)
    {
        await using var cmd = CreateCommand(conn, sql, ps);
        await cmd.ExecuteNonQueryAsync(ct);
        return cmd.LastInsertedId;
    }

    public static async Task<long> ScalarLongAsync(
        IDbConnection conn, string sql, CancellationToken ct, params (string name, object? value)[] ps)
    {
        await using var cmd = CreateCommand(conn, sql, ps);
        var result = await cmd.ExecuteScalarAsync(ct);
        return result is null or DBNull ? 0 : Convert.ToInt64(result);
    }

    public static async Task<decimal> ScalarDecimalAsync(
        IDbConnection conn, string sql, CancellationToken ct, params (string name, object? value)[] ps)
    {
        await using var cmd = CreateCommand(conn, sql, ps);
        var result = await cmd.ExecuteScalarAsync(ct);
        return result is null or DBNull ? 0m : Convert.ToDecimal(result);
    }

    // ---- null-safe readers ----
    public static string GetString(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? string.Empty : r.GetString(i);
    }

    public static string? GetStringOrNull(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? null : r.GetString(i);
    }

    public static long GetLong(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? 0 : Convert.ToInt64(r.GetValue(i));
    }

    public static long? GetLongOrNull(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? null : Convert.ToInt64(r.GetValue(i));
    }

    public static int GetInt(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? 0 : Convert.ToInt32(r.GetValue(i));
    }

    public static int? GetIntOrNull(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? null : Convert.ToInt32(r.GetValue(i));
    }

    public static decimal GetDecimal(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? 0m : Convert.ToDecimal(r.GetValue(i));
    }

    /// <summary>
    /// A decimal column that means something different when it is NULL. <see cref="GetDecimal"/>
    /// flattens NULL to zero, which is right for an amount and wrong for a measurement: an
    /// unrecorded distance is not a distance of nought.
    /// </summary>
    public static decimal? GetDecimalOrNull(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? null : Convert.ToDecimal(r.GetValue(i));
    }

    public static bool GetBool(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return !r.IsDBNull(i) && Convert.ToBoolean(r.GetValue(i));
    }

    public static DateTime GetDate(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? default : r.GetDateTime(i);
    }

    public static DateTime? GetDateOrNull(this IDataRecord r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? null : r.GetDateTime(i);
    }
}
