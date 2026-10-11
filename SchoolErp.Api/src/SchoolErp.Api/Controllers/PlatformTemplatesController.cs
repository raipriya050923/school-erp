using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Messaging;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

/// <summary>
/// The message library. The platform writes every SMS and email the product sends, and decides
/// per message whether a school may reword it.
/// </summary>
[ApiController]
[Route("api/super-admin/templates")]
[Authorize(Roles = "super_admin")]
public class PlatformTemplatesController : ControllerBase
{
    private readonly IMessageTemplateService _service;
    public PlatformTemplatesController(IMessageTemplateService service) => _service = service;

    /// <summary>Every default. `channel` narrows to sms or email; omitted returns both.</summary>
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? channel, CancellationToken ct)
        => Ok(await _service.ListPlatformAsync(channel, ct));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveTemplateDto dto, CancellationToken ct)
        => Ok(new { id = await _service.CreateAsync(dto, ct) });

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] SaveTemplateDto dto, CancellationToken ct)
    {
        await _service.UpdatePlatformAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>
    /// Removes a default outright. Refused once any school has its own version, because that
    /// would leave their override pointing at nothing — switch it off instead.
    /// </summary>
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken ct)
    {
        await _service.DeletePlatformAsync(id, ct);
        return NoContent();
    }

    /// <summary>
    /// What a body renders to for a given set of values, before it is saved or sent. Reports
    /// the placeholders nothing was supplied for.
    /// </summary>
    [HttpPost("preview")]
    public IActionResult Preview([FromBody] PreviewRequest request)
        => Ok(_service.Preview(request.Subject, request.Body,
            request.Values ?? new Dictionary<string, string?>()));

    public class PreviewRequest
    {
        public string? Subject { get; set; }
        public string Body { get; set; } = string.Empty;
        public Dictionary<string, string?>? Values { get; set; }
    }
}
