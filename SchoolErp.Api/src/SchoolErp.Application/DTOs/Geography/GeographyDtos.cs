namespace SchoolErp.Application.DTOs.Geography;

public record CountryDto(long Id, string Name, string Iso2, string? PhoneCode, string? Currency, bool IsActive);
public record StateDto(long Id, long CountryId, string? CountryName, string Name, string? Code, bool IsActive);
public record CityDto(long Id, long StateId, string? StateName, string? CountryName, string Name, bool IsActive);

public class SaveCountryDto
{
    public string Name { get; set; } = string.Empty;
    public string Iso2 { get; set; } = string.Empty;
    public string? PhoneCode { get; set; }
    public string? Currency { get; set; }
}

public class SaveStateDto
{
    public long CountryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Code { get; set; }
}

public class SaveCityDto
{
    public long StateId { get; set; }
    public string Name { get; set; } = string.Empty;
}

/// <summary>
/// The resolved place for a school, student or staff member. Ids are what gets
/// stored; the names ride along so a list can be rendered without extra lookups.
/// </summary>
public record PlaceDto(
    long? CountryId, string? CountryName,
    long? StateId, string? StateName,
    long? CityId, string? CityName);
