using SchoolErp.Application.DTOs.Geography;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>
/// The platform-wide country/state/city master. Reads are open to any signed-in
/// user because every school's forms need them; writes belong to the super admin.
/// </summary>
public interface IGeographyService
{
    Task<IReadOnlyList<CountryDto>> CountriesAsync(bool activeOnly, CancellationToken ct = default);
    Task<IReadOnlyList<StateDto>> StatesAsync(long? countryId, bool activeOnly, CancellationToken ct = default);
    Task<IReadOnlyList<CityDto>> CitiesAsync(long? stateId, bool activeOnly, CancellationToken ct = default);

    /// <summary>
    /// Checks a country/state/city triple hangs together and returns the resolved names,
    /// so callers can store ids and keep their denormalised text columns in step.
    /// </summary>
    Task<PlaceDto> ResolveAsync(long? countryId, long? stateId, long? cityId, CancellationToken ct = default);

    Task<long> CreateCountryAsync(SaveCountryDto dto, CancellationToken ct = default);
    Task UpdateCountryAsync(long id, SaveCountryDto dto, CancellationToken ct = default);
    Task SetCountryActiveAsync(long id, bool isActive, CancellationToken ct = default);

    Task<long> CreateStateAsync(SaveStateDto dto, CancellationToken ct = default);
    Task UpdateStateAsync(long id, SaveStateDto dto, CancellationToken ct = default);
    Task SetStateActiveAsync(long id, bool isActive, CancellationToken ct = default);

    Task<long> CreateCityAsync(SaveCityDto dto, CancellationToken ct = default);
    Task UpdateCityAsync(long id, SaveCityDto dto, CancellationToken ct = default);
    Task SetCityActiveAsync(long id, bool isActive, CancellationToken ct = default);
}
