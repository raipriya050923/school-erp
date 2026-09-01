namespace SchoolErp.Domain.Entities;

/// <summary>
/// Platform-level geography. Unlike subjects or leave types these are not scoped
/// to a school — one list is shared by every tenant, maintained by the super admin.
/// </summary>
public class Country
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Iso2 { get; set; } = string.Empty;
    public string? PhoneCode { get; set; }
    public string? Currency { get; set; }
    public bool IsActive { get; set; } = true;
}

public class StateRegion
{
    public long Id { get; set; }
    public long CountryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Code { get; set; }
    public bool IsActive { get; set; } = true;

    /// <summary>Joined for display — not a column.</summary>
    public string? CountryName { get; set; }
}

public class City
{
    public long Id { get; set; }
    public long StateId { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;

    // Joined for display — not columns.
    public string? StateName { get; set; }
    public string? CountryName { get; set; }
}
