using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/teachers")]
[Authorize(Roles = "school_admin")]
public class AdminTeachersController : ControllerBase
{
    private readonly ITeacherService _service;
    private readonly IAccountResetService _accounts;

    public AdminTeachersController(ITeacherService service, IAccountResetService accounts)
    {
        _service = service;
        _accounts = accounts;
    }

    /// <summary>Whether this teacher has a portal login, so the screen knows what to offer.</summary>
    [HttpGet("{id:long}/login")]
    public async Task<IActionResult> Login(long id, CancellationToken ct)
        => Ok(await _accounts.TeacherLoginAsync(id, ct));

    /// <summary>
    /// Issues a new password for the teacher's login. The response carries it in plaintext and
    /// that is the only time it exists — the account stores a hash — so the caller must show it
    /// once and not store it. The teacher is forced to replace it at their next sign-in.
    /// </summary>
    [HttpPost("{id:long}/reset-password")]
    public async Task<IActionResult> ResetPassword(long id, [FromBody] ResetAccountPasswordDto? dto, CancellationToken ct)
        => Ok(await _accounts.ResetTeacherAsync(id, dto ?? new ResetAccountPasswordDto(), ct));

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, CancellationToken ct)
        => Ok(await _service.ListAsync(search, ct));

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        var t = await _service.GetAsync(id, ct);
        return t is null ? NotFound() : Ok(t);
    }

    /// <summary>
    /// Registers a teacher and provisions their portal login. The response carries the generated
    /// password in plaintext — it is never persisted or retrievable afterwards, so the caller
    /// must surface it to the admin immediately.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveTeacherDto dto, CancellationToken ct)
        => Ok(await _service.CreateAsync(dto, ct));

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] SaveTeacherDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    [HttpPatch("{id:long}/status")]
    public async Task<IActionResult> SetStatus(long id, [FromBody] UpdateStatusDto dto, CancellationToken ct)
    {
        await _service.SetStatusAsync(id, dto.Status, ct);
        return NoContent();
    }
}
