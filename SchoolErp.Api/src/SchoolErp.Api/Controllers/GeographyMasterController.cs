using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Geography;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

/// <summary>
/// Maintains the shared geography master. Platform-level on purpose: one list is
/// used by every tenant, so only the super admin may change it. Rows are retired
/// rather than deleted, since schools and students already point at them.
/// </summary>
[ApiController]
[Route("api/super-admin/geography")]
[Authorize(Roles = "super_admin")]
public class GeographyMasterController : ControllerBase
{
    private readonly IGeographyService _service;
    public GeographyMasterController(IGeographyService service) => _service = service;

    // ----------------------------------------------------------- countries

    /// <summary>Includes retired entries, which the school-facing endpoint hides.</summary>
    [HttpGet("countries")]
    public async Task<IActionResult> Countries(CancellationToken ct)
        => Ok(await _service.CountriesAsync(activeOnly: false, ct));

    [HttpPost("countries")]
    public async Task<IActionResult> CreateCountry([FromBody] SaveCountryDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateCountryAsync(dto, ct) });

    [HttpPut("countries/{id:long}")]
    public async Task<IActionResult> UpdateCountry(long id, [FromBody] SaveCountryDto dto, CancellationToken ct)
    {
        await _service.UpdateCountryAsync(id, dto, ct);
        return NoContent();
    }

    [HttpPatch("countries/{id:long}/active")]
    public async Task<IActionResult> SetCountryActive(long id, [FromQuery] bool value, CancellationToken ct)
    {
        await _service.SetCountryActiveAsync(id, value, ct);
        return NoContent();
    }

    // -------------------------------------------------------------- states

    [HttpGet("states")]
    public async Task<IActionResult> States([FromQuery] long? countryId, CancellationToken ct)
        => Ok(await _service.StatesAsync(countryId, activeOnly: false, ct));

    [HttpPost("states")]
    public async Task<IActionResult> CreateState([FromBody] SaveStateDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateStateAsync(dto, ct) });

    [HttpPut("states/{id:long}")]
    public async Task<IActionResult> UpdateState(long id, [FromBody] SaveStateDto dto, CancellationToken ct)
    {
        await _service.UpdateStateAsync(id, dto, ct);
        return NoContent();
    }

    [HttpPatch("states/{id:long}/active")]
    public async Task<IActionResult> SetStateActive(long id, [FromQuery] bool value, CancellationToken ct)
    {
        await _service.SetStateActiveAsync(id, value, ct);
        return NoContent();
    }

    // -------------------------------------------------------------- cities

    [HttpGet("cities")]
    public async Task<IActionResult> Cities([FromQuery] long? stateId, CancellationToken ct)
        => Ok(await _service.CitiesAsync(stateId, activeOnly: false, ct));

    [HttpPost("cities")]
    public async Task<IActionResult> CreateCity([FromBody] SaveCityDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateCityAsync(dto, ct) });

    [HttpPut("cities/{id:long}")]
    public async Task<IActionResult> UpdateCity(long id, [FromBody] SaveCityDto dto, CancellationToken ct)
    {
        await _service.UpdateCityAsync(id, dto, ct);
        return NoContent();
    }

    [HttpPatch("cities/{id:long}/active")]
    public async Task<IActionResult> SetCityActive(long id, [FromQuery] bool value, CancellationToken ct)
    {
        await _service.SetCityActiveAsync(id, value, ct);
        return NoContent();
    }
}
