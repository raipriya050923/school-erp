using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Messaging;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

/// <summary>
/// Every message that goes out in this school's name, and the ones it may reword.
///
/// A school never creates a template: the codes are what the sending code asks for, so one a
/// school invented would be sent by nothing. It overrides a default, or it inherits it.
/// </summary>
[ApiController]
[Route("api/admin/templates")]
[Authorize(Roles = "school_admin")]
public class AdminTemplatesController : ControllerBase
{
    private readonly IMessageTemplateService _service;
    public AdminTemplatesController(IMessageTemplateService service) => _service = service;

    /// <summary>
    /// The resolved list: this school's wording where it has its own, the platform's where it
    /// has not, with `canEdit` saying which is which.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
        => Ok(await _service.ListForSchoolAsync(ct));

    /// <summary>
    /// Supplies this school's own wording. Refused with 400 when the platform reserved this
    /// message — the console hides the control, but the rule lives here.
    /// </summary>
    [HttpPut("{channel}/{code}")]
    public async Task<IActionResult> Save(
        string channel, string code, [FromQuery] string locale,
        [FromBody] SaveSchoolTemplateDto dto, CancellationToken ct)
    {
        await _service.SaveSchoolOverrideAsync(channel, code, locale, dto, ct);
        return NoContent();
    }

    /// <summary>Drops back to the platform's wording.</summary>
    [HttpDelete("{channel}/{code}")]
    public async Task<IActionResult> Clear(
        string channel, string code, [FromQuery] string locale, CancellationToken ct)
    {
        await _service.ClearSchoolOverrideAsync(channel, code, locale, ct);
        return NoContent();
    }
}
