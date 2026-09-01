using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Geography;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Domain.Entities;

namespace SchoolErp.Application.Services;

/// <inheritdoc />
public class GeographyService : IGeographyService
{
    private readonly IGeographyRepository _repo;

    public GeographyService(IGeographyRepository repo) => _repo = repo;

    // --------------------------------------------------------------- reads

    public async Task<IReadOnlyList<CountryDto>> CountriesAsync(bool activeOnly, CancellationToken ct = default) =>
        (await _repo.GetCountriesAsync(activeOnly, ct))
        .Select(c => new CountryDto(c.Id, c.Name, c.Iso2, c.PhoneCode, c.Currency, c.IsActive)).ToList();

    public async Task<IReadOnlyList<StateDto>> StatesAsync(long? countryId, bool activeOnly, CancellationToken ct = default) =>
        (await _repo.GetStatesAsync(countryId, activeOnly, ct))
        .Select(s => new StateDto(s.Id, s.CountryId, s.CountryName, s.Name, s.Code, s.IsActive)).ToList();

    public async Task<IReadOnlyList<CityDto>> CitiesAsync(long? stateId, bool activeOnly, CancellationToken ct = default) =>
        (await _repo.GetCitiesAsync(stateId, activeOnly, ct))
        .Select(c => new CityDto(c.Id, c.StateId, c.StateName, c.CountryName, c.Name, c.IsActive)).ToList();

    /// <summary>
    /// Validates a country/state/city triple and returns the resolved names. Each level must sit
    /// under the one above it, so a caller cannot pair a Nepali city with an Indian state.
    /// </summary>
    public async Task<PlaceDto> ResolveAsync(long? countryId, long? stateId, long? cityId, CancellationToken ct = default)
    {
        Country? country = null;
        StateRegion? state = null;
        City? city = null;

        if (cityId is { } ci)
        {
            city = await _repo.GetCityAsync(ci, ct)
                   ?? throw new ValidationException("That city is not in the master list.");
            state = await _repo.GetStateAsync(city.StateId, ct);
            if (stateId is { } sid && sid != city.StateId)
                throw new ValidationException($"{city.Name} does not belong to the selected state.");
        }
        else if (stateId is { } sid2)
        {
            state = await _repo.GetStateAsync(sid2, ct)
                    ?? throw new ValidationException("That state is not in the master list.");
        }

        if (state is not null)
        {
            country = await _repo.GetCountryAsync(state.CountryId, ct);
            if (countryId is { } cid && cid != state.CountryId)
                throw new ValidationException($"{state.Name} does not belong to the selected country.");
        }
        else if (countryId is { } cid2)
        {
            country = await _repo.GetCountryAsync(cid2, ct)
                      ?? throw new ValidationException("That country is not in the master list.");
        }

        return new PlaceDto(
            country?.Id, country?.Name,
            state?.Id, state?.Name,
            city?.Id, city?.Name);
    }

    // -------------------------------------------------------------- writes

    public async Task<long> CreateCountryAsync(SaveCountryDto dto, CancellationToken ct = default)
    {
        var (name, iso) = ValidateCountry(dto);
        if (await _repo.CountryExistsByNameAsync(name, null, ct))
            throw new ValidationException($"“{name}” already exists.");
        return await _repo.CreateCountryAsync(new Country
        {
            Name = name, Iso2 = iso,
            PhoneCode = Clean(dto.PhoneCode),
            Currency = Clean(dto.Currency)?.ToUpperInvariant(),
            IsActive = true,
        }, ct);
    }

    public async Task UpdateCountryAsync(long id, SaveCountryDto dto, CancellationToken ct = default)
    {
        var (name, iso) = ValidateCountry(dto);
        var country = await _repo.GetCountryAsync(id, ct)
                      ?? throw new NotFoundException($"Country {id} not found.");
        if (await _repo.CountryExistsByNameAsync(name, id, ct))
            throw new ValidationException($"“{name}” already exists.");
        country.Name = name;
        country.Iso2 = iso;
        country.PhoneCode = Clean(dto.PhoneCode);
        country.Currency = Clean(dto.Currency)?.ToUpperInvariant();
        await _repo.UpdateCountryAsync(country, ct);
    }

    public async Task<long> CreateStateAsync(SaveStateDto dto, CancellationToken ct = default)
    {
        var name = Required(dto.Name, "State name");
        _ = await _repo.GetCountryAsync(dto.CountryId, ct)
            ?? throw new ValidationException("Choose a country for this state.");
        if (await _repo.StateExistsByNameAsync(dto.CountryId, name, null, ct))
            throw new ValidationException($"“{name}” already exists in that country.");
        return await _repo.CreateStateAsync(new StateRegion
        {
            CountryId = dto.CountryId, Name = name,
            Code = Clean(dto.Code)?.ToUpperInvariant(), IsActive = true,
        }, ct);
    }

    public async Task UpdateStateAsync(long id, SaveStateDto dto, CancellationToken ct = default)
    {
        var name = Required(dto.Name, "State name");
        var state = await _repo.GetStateAsync(id, ct)
                    ?? throw new NotFoundException($"State {id} not found.");
        if (await _repo.StateExistsByNameAsync(state.CountryId, name, id, ct))
            throw new ValidationException($"“{name}” already exists in that country.");
        state.Name = name;
        state.Code = Clean(dto.Code)?.ToUpperInvariant();
        await _repo.UpdateStateAsync(state, ct);
    }

    public async Task<long> CreateCityAsync(SaveCityDto dto, CancellationToken ct = default)
    {
        var name = Required(dto.Name, "City name");
        _ = await _repo.GetStateAsync(dto.StateId, ct)
            ?? throw new ValidationException("Choose a state for this city.");
        if (await _repo.CityExistsByNameAsync(dto.StateId, name, null, ct))
            throw new ValidationException($"“{name}” already exists in that state.");
        return await _repo.CreateCityAsync(new City
        {
            StateId = dto.StateId, Name = name, IsActive = true,
        }, ct);
    }

    public async Task UpdateCityAsync(long id, SaveCityDto dto, CancellationToken ct = default)
    {
        var name = Required(dto.Name, "City name");
        var city = await _repo.GetCityAsync(id, ct)
                   ?? throw new NotFoundException($"City {id} not found.");
        if (await _repo.CityExistsByNameAsync(city.StateId, name, id, ct))
            throw new ValidationException($"“{name}” already exists in that state.");
        city.Name = name;
        await _repo.UpdateCityAsync(city, ct);
    }

    public async Task SetCountryActiveAsync(long id, bool isActive, CancellationToken ct = default)
    {
        _ = await _repo.GetCountryAsync(id, ct) ?? throw new NotFoundException($"Country {id} not found.");
        await _repo.SetCountryActiveAsync(id, isActive, ct);
    }

    public async Task SetStateActiveAsync(long id, bool isActive, CancellationToken ct = default)
    {
        _ = await _repo.GetStateAsync(id, ct) ?? throw new NotFoundException($"State {id} not found.");
        await _repo.SetStateActiveAsync(id, isActive, ct);
    }

    public async Task SetCityActiveAsync(long id, bool isActive, CancellationToken ct = default)
    {
        _ = await _repo.GetCityAsync(id, ct) ?? throw new NotFoundException($"City {id} not found.");
        await _repo.SetCityActiveAsync(id, isActive, ct);
    }

    // ---------------------------------------------------------- validation

    private static (string Name, string Iso2) ValidateCountry(SaveCountryDto dto)
    {
        var name = Required(dto.Name, "Country name");
        var iso = (dto.Iso2 ?? "").Trim().ToUpperInvariant();
        if (iso.Length != 2)
            throw new ValidationException("ISO code must be exactly two letters, e.g. NP or IN.");
        return (name, iso);
    }

    private static string Required(string? value, string label)
    {
        var v = (value ?? "").Trim();
        if (v.Length == 0) throw new ValidationException($"{label} is required.");
        return v;
    }

    private static string? Clean(string? v) =>
        string.IsNullOrWhiteSpace(v) ? null : v.Trim();
}
