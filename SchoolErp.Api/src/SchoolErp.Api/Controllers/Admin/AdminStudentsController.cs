using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Schools;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/students")]
[Authorize(Roles = "school_admin")]
public class AdminStudentsController : ControllerBase
{
    private readonly IStudentService _service;
    private readonly IStudentImportService _import;
    private readonly IParentAccountService _parents;
    private readonly IAccountResetService _accounts;

    public AdminStudentsController(IStudentService service, IStudentImportService import,
        IParentAccountService parents, IAccountResetService accounts)
    {
        _service = service;
        _import = import;
        _parents = parents;
        _accounts = accounts;
    }

    /// <summary>A sample workbook with the expected headers and the school's own classes filled in.</summary>
    [HttpGet("import/template")]
    public async Task<IActionResult> Template(CancellationToken ct)
    {
        var (content, name) = await _import.TemplateAsync(ct);
        return File(content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", name);
    }

    /// <summary>
    /// Admits every valid row of an uploaded .xlsx or .csv. Invalid rows are reported and skipped
    /// rather than failing the whole file. With <paramref name="dryRun"/> nothing is written —
    /// the sheet is only checked, so an admin can see what would happen first.
    ///
    /// The response carries each new login's password in plaintext. It exists nowhere else, so
    /// the caller has to surface it immediately.
    /// </summary>
    [HttpPost("import")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<IActionResult> Import(IFormFile? file, [FromQuery] bool dryRun, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            return BadRequest(new { error = "validation_error", message = "Choose a file to import." });
        await using var stream = file.OpenReadStream();
        return Ok(await _import.ImportAsync(stream, file.FileName, dryRun, ct));
    }

    /// <summary>
    /// One page of the roster. Every filter is applied server-side, so the totals shown beside
    /// the pager describe the whole result rather than the page in hand.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? search, [FromQuery] string? className,
        [FromQuery] DateTime? admittedFrom, [FromQuery] DateTime? admittedTo,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 25, CancellationToken ct = default)
        => Ok(await _service.ListAsync(search, className, admittedFrom, admittedTo, page, pageSize, ct));

    /// <summary>Whether this student has a portal login, so the screen knows what to offer.</summary>
    [HttpGet("{id:long}/login")]
    public async Task<IActionResult> Login(long id, CancellationToken ct)
        => Ok(await _accounts.StudentLoginAsync(id, ct));

    /// <summary>
    /// Issues a new password for the student's own login. Plaintext in the response and nowhere
    /// else; the student must replace it at their next sign-in.
    /// </summary>
    [HttpPost("{id:long}/reset-password")]
    public async Task<IActionResult> ResetPassword(long id, [FromBody] ResetAccountPasswordDto? dto, CancellationToken ct)
        => Ok(await _accounts.ResetStudentAsync(id, dto ?? new ResetAccountPasswordDto(), ct));

    /// <summary>
    /// The same for the guardian's login — the account a parent signs in with. Issuing a second
    /// parent account is refused elsewhere precisely because this exists.
    /// </summary>
    [HttpPost("{id:long}/parent-login/reset-password")]
    public async Task<IActionResult> ResetParentPassword(long id, [FromBody] ResetAccountPasswordDto? dto, CancellationToken ct)
        => Ok(await _accounts.ResetParentAsync(id, dto ?? new ResetAccountPasswordDto(), ct));

    /// <summary>Next free roll number for a class/section — a preview for the admission form.</summary>
    [HttpGet("next-roll")]
    public async Task<IActionResult> NextRoll([FromQuery] string? className, [FromQuery] string? sectionName, CancellationToken ct)
        => Ok(new { rollNo = await _service.NextRollNoAsync(className, sectionName, ct) });

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        var s = await _service.GetAsync(id, ct);
        return s is null ? NotFound() : Ok(s);
    }

    /// <summary>
    /// Admits a student and provisions their portal login. The response carries the generated
    /// password in plaintext — it is never persisted or retrievable afterwards, so the caller
    /// must surface it to the admin immediately.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveStudentDto dto, CancellationToken ct)
        => Ok(await _service.CreateAsync(dto, ct));

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] SaveStudentDto dto, CancellationToken ct)
    {
        await _service.UpdateAsync(id, dto, ct);
        return NoContent();
    }

    /// <summary>The guardian on this student, and whether they can sign in yet.</summary>
    [HttpGet("{id:long}/parent-login")]
    public async Task<IActionResult> ParentLogin(long id, CancellationToken ct)
        => Ok(await _parents.GetAsync(id, ct));

    /// <summary>
    /// Issues a login for this student's parent. The credentials come back once
    /// and are not stored in plaintext, so the console must show them immediately.
    /// </summary>
    [HttpPost("{id:long}/parent-login")]
    public async Task<IActionResult> CreateParentLogin(long id, [FromBody] CreateParentLoginDto dto, CancellationToken ct)
        => Ok(await _parents.CreateLoginAsync(id, dto, ct));

    [HttpPatch("{id:long}/status")]
    public async Task<IActionResult> SetStatus(long id, [FromBody] UpdateStatusDto dto, CancellationToken ct)
    {
        await _service.SetStatusAsync(id, dto.Status, ct);
        return NoContent();
    }
}
