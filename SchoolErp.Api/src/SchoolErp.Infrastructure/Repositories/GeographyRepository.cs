using System.Data;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Domain.Entities;
using SchoolErp.Infrastructure.Persistence;

namespace SchoolErp.Infrastructure.Repositories;

public class GeographyRepository : IGeographyRepository
{
    private readonly IDbConnectionFactory _factory;
    public GeographyRepository(IDbConnectionFactory factory) => _factory = factory;

    // --------------------------------------------------------------- reads

    public async Task<IReadOnlyList<Country>> GetCountriesAsync(bool activeOnly, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT id, name, iso2, phone_code, currency, is_active FROM countries";
        if (activeOnly) sql += " WHERE is_active=1";
        sql += " ORDER BY name";
        return await DbHelper.QueryAsync(conn, sql, MapCountry, ct);
    }

    public async Task<IReadOnlyList<StateRegion>> GetStatesAsync(long? countryId, bool activeOnly, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = @"SELECT s.id, s.country_id, s.name, s.code, s.is_active, c.name AS country_name
                    FROM states s JOIN countries c ON c.id = s.country_id WHERE 1=1";
        var ps = new List<(string, object?)>();
        if (countryId.HasValue) { sql += " AND s.country_id=@cid"; ps.Add(("@cid", countryId.Value)); }
        if (activeOnly) sql += " AND s.is_active=1";
        sql += " ORDER BY s.name";
        return await DbHelper.QueryAsync(conn, sql, MapState, ct, ps.ToArray());
    }

    public async Task<IReadOnlyList<City>> GetCitiesAsync(long? stateId, bool activeOnly, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = @"SELECT ci.id, ci.state_id, ci.name, ci.is_active,
                           s.name AS state_name, co.name AS country_name
                    FROM cities ci
                    JOIN states s     ON s.id = ci.state_id
                    JOIN countries co ON co.id = s.country_id
                    WHERE 1=1";
        var ps = new List<(string, object?)>();
        if (stateId.HasValue) { sql += " AND ci.state_id=@sid"; ps.Add(("@sid", stateId.Value)); }
        if (activeOnly) sql += " AND ci.is_active=1";
        sql += " ORDER BY ci.name";
        return await DbHelper.QueryAsync(conn, sql, MapCity, ct, ps.ToArray());
    }

    public async Task<Country?> GetCountryAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            "SELECT id, name, iso2, phone_code, currency, is_active FROM countries WHERE id=@id",
            MapCountry, ct, ("@id", id));
    }

    public async Task<StateRegion?> GetStateAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            @"SELECT s.id, s.country_id, s.name, s.code, s.is_active, c.name AS country_name
              FROM states s JOIN countries c ON c.id = s.country_id WHERE s.id=@id",
            MapState, ct, ("@id", id));
    }

    public async Task<City?> GetCityAsync(long id, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.QuerySingleAsync(conn,
            @"SELECT ci.id, ci.state_id, ci.name, ci.is_active,
                     s.name AS state_name, co.name AS country_name
              FROM cities ci
              JOIN states s     ON s.id = ci.state_id
              JOIN countries co ON co.id = s.country_id
              WHERE ci.id=@id",
            MapCity, ct, ("@id", id));
    }

    // -------------------------------------------------------------- writes

    public async Task<long> CreateCountryAsync(Country c, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn,
            @"INSERT INTO countries (name, iso2, phone_code, currency, is_active)
              VALUES (@n, @iso, @ph, @cur, @a)", ct,
            ("@n", c.Name), ("@iso", c.Iso2), ("@ph", c.PhoneCode),
            ("@cur", c.Currency), ("@a", c.IsActive));
    }

    public async Task<long> CreateStateAsync(StateRegion s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn,
            "INSERT INTO states (country_id, name, code, is_active) VALUES (@cid, @n, @c, @a)", ct,
            ("@cid", s.CountryId), ("@n", s.Name), ("@c", s.Code), ("@a", s.IsActive));
    }

    public async Task<long> CreateCityAsync(City c, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        return await DbHelper.InsertAsync(conn,
            "INSERT INTO cities (state_id, name, is_active) VALUES (@sid, @n, @a)", ct,
            ("@sid", c.StateId), ("@n", c.Name), ("@a", c.IsActive));
    }

    public async Task UpdateCountryAsync(Country c, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE countries SET name=@n, iso2=@iso, phone_code=@ph, currency=@cur WHERE id=@id", ct,
            ("@n", c.Name), ("@iso", c.Iso2), ("@ph", c.PhoneCode), ("@cur", c.Currency), ("@id", c.Id));
    }

    public async Task UpdateStateAsync(StateRegion s, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE states SET name=@n, code=@c WHERE id=@id", ct,
            ("@n", s.Name), ("@c", s.Code), ("@id", s.Id));
    }

    public async Task UpdateCityAsync(City c, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            "UPDATE cities SET name=@n WHERE id=@id", ct, ("@n", c.Name), ("@id", c.Id));
    }

    public Task SetCountryActiveAsync(long id, bool isActive, CancellationToken ct = default)
        => SetActiveAsync("countries", id, isActive, ct);
    public Task SetStateActiveAsync(long id, bool isActive, CancellationToken ct = default)
        => SetActiveAsync("states", id, isActive, ct);
    public Task SetCityActiveAsync(long id, bool isActive, CancellationToken ct = default)
        => SetActiveAsync("cities", id, isActive, ct);

    /// <summary>`table` is a compile-time literal from the three callers above — never user input.</summary>
    private async Task SetActiveAsync(string table, long id, bool isActive, CancellationToken ct)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        await DbHelper.ExecuteAsync(conn,
            $"UPDATE {table} SET is_active=@a WHERE id=@id", ct, ("@a", isActive), ("@id", id));
    }

    // ----------------------------------------------------------- uniqueness

    public async Task<bool> CountryExistsByNameAsync(string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM countries WHERE name=@n";
        var ps = new List<(string, object?)> { ("@n", name) };
        if (excludeId.HasValue) { sql += " AND id<>@id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    public async Task<bool> StateExistsByNameAsync(long countryId, string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM states WHERE country_id=@cid AND name=@n";
        var ps = new List<(string, object?)> { ("@cid", countryId), ("@n", name) };
        if (excludeId.HasValue) { sql += " AND id<>@id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    public async Task<bool> CityExistsByNameAsync(long stateId, string name, long? excludeId, CancellationToken ct = default)
    {
        using var conn = await _factory.CreateOpenConnectionAsync(ct);
        var sql = "SELECT COUNT(*) FROM cities WHERE state_id=@sid AND name=@n";
        var ps = new List<(string, object?)> { ("@sid", stateId), ("@n", name) };
        if (excludeId.HasValue) { sql += " AND id<>@id"; ps.Add(("@id", excludeId.Value)); }
        return await DbHelper.ScalarLongAsync(conn, sql, ct, ps.ToArray()) > 0;
    }

    // ---------------------------------------------------------------- maps

    private static Country MapCountry(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        Name = r.GetString("name"),
        Iso2 = r.GetString("iso2"),
        PhoneCode = r.GetStringOrNull("phone_code"),
        Currency = r.GetStringOrNull("currency"),
        IsActive = r.GetBool("is_active"),
    };

    private static StateRegion MapState(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        CountryId = r.GetLong("country_id"),
        Name = r.GetString("name"),
        Code = r.GetStringOrNull("code"),
        IsActive = r.GetBool("is_active"),
        CountryName = r.GetStringOrNull("country_name"),
    };

    private static City MapCity(IDataRecord r) => new()
    {
        Id = r.GetLong("id"),
        StateId = r.GetLong("state_id"),
        Name = r.GetString("name"),
        IsActive = r.GetBool("is_active"),
        StateName = r.GetStringOrNull("state_name"),
        CountryName = r.GetStringOrNull("country_name"),
    };
}
