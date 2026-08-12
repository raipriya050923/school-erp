using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Plans;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/super-admin/plans")]
public class PlansController : ControllerBase
{
    private readonly IPlanService _service;
    public PlansController(IPlanService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) => Ok(await _service.ListAsync(ct));

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        var plan = await _service.GetAsync(id, ct);
        return plan is null ? NotFound() : Ok(plan);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreatePlanDto dto, CancellationToken ct)
    {
        var id = await _service.CreateAsync(dto, ct);
        return CreatedAtAction(nameof(Get), new { id }, new { id });
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] UpdatePlanDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    [HttpPatch("{id:long}/active")]
    public async Task<IActionResult> SetActive(long id, [FromQuery] bool value, CancellationToken ct)
    {
        await _service.SetActiveAsync(id, value, ct);
        return NoContent();
    }
}
