using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

/// <summary>
/// Academic years for the caller's school — backs the year selector in the top bar. Open to any
/// signed-in tenant user; platform staff have no school and get an empty list.
/// </summary>
[ApiController]
[Route("api/academic-years")]
[Authorize]
public class AcademicYearsController : ControllerBase
{
    private readonly ISchoolRepository _schools;
    private readonly ICurrentUser _user;

    public AcademicYearsController(ISchoolRepository schools, ICurrentUser user)
    {
        _schools = schools;
        _user = user;
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        if (_user.SchoolId is not { } schoolId) return Ok(Array.Empty<object>());
        var rows = await _schools.GetAcademicYearsAsync(schoolId, ct);
        return Ok(rows.Select(r => new { id = r.Id, name = r.Name, isCurrent = r.IsCurrent }));
    }
}
