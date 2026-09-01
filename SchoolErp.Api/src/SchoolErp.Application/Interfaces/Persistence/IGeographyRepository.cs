using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Interfaces.Persistence;

/// <summary>
/// The shared country/state/city master. No school id anywhere — this data is
/// platform-wide, so every tenant reads the same rows.
/// </summary>
public interface IGeographyRepository
{
    Task<IReadOnlyList<Country>> GetCountriesAsync(bool activeOnly, CancellationToken ct = default);
    Task<IReadOnlyList<StateRegion>> GetStatesAsync(long? countryId, bool activeOnly, CancellationToken ct = default);
    Task<IReadOnlyList<City>> GetCitiesAsync(long? stateId, bool activeOnly, CancellationToken ct = default);

    Task<Country?> GetCountryAsync(long id, CancellationToken ct = default);
    Task<StateRegion?> GetStateAsync(long id, CancellationToken ct = default);
    Task<City?> GetCityAsync(long id, CancellationToken ct = default);

    Task<long> CreateCountryAsync(Country c, CancellationToken ct = default);
    Task<long> CreateStateAsync(StateRegion s, CancellationToken ct = default);
    Task<long> CreateCityAsync(City c, CancellationToken ct = default);

    Task UpdateCountryAsync(Country c, CancellationToken ct = default);
    Task UpdateStateAsync(StateRegion s, CancellationToken ct = default);
    Task UpdateCityAsync(City c, CancellationToken ct = default);

    Task SetCountryActiveAsync(long id, bool isActive, CancellationToken ct = default);
    Task SetStateActiveAsync(long id, bool isActive, CancellationToken ct = default);
    Task SetCityActiveAsync(long id, bool isActive, CancellationToken ct = default);

    Task<bool> CountryExistsByNameAsync(string name, long? excludeId, CancellationToken ct = default);
    Task<bool> StateExistsByNameAsync(long countryId, string name, long? excludeId, CancellationToken ct = default);
    Task<bool> CityExistsByNameAsync(long stateId, string name, long? excludeId, CancellationToken ct = default);
}
