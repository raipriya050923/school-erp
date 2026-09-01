using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

/// <summary>
/// Read-only geography for the cascading Country → State → City pickers.
/// Open to any signed-in user: school admins need it on the admission and staff
/// forms, so it is not locked to a role the way the super-admin master is.
/// Only active rows are returned; retired ones stay for historical records.
/// </summary>
[ApiController]
[Route("api/geography")]
[Authorize]
public class GeographyController : ControllerBase
{
    private readonly IGeographyService _service;
    public GeographyController(IGeographyService service) => _service = service;

    [HttpGet("countries")]
    public async Task<IActionResult> Countries(CancellationToken ct)
        => Ok(await _service.CountriesAsync(activeOnly: true, ct));

    /// <summary>States in a country. Without <paramref name="countryId"/> this returns every state.</summary>
    [HttpGet("states")]
    public async Task<IActionResult> States([FromQuery] long? countryId, CancellationToken ct)
        => Ok(await _service.StatesAsync(countryId, activeOnly: true, ct));

    /// <summary>Cities in a state. Without <paramref name="stateId"/> this returns every city.</summary>
    [HttpGet("cities")]
    public async Task<IActionResult> Cities([FromQuery] long? stateId, CancellationToken ct)
        => Ok(await _service.CitiesAsync(stateId, activeOnly: true, ct));
}
