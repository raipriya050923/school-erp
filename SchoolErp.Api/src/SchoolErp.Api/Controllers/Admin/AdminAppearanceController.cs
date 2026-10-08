using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

/// <summary>
/// The school's own shell colour. A super admin sets it when onboarding, but the person who
/// actually cares which colour the school wears is its administrator, so they can change it here
/// without going through the platform.
/// </summary>
[ApiController]
[Route("api/admin/appearance")]
[Authorize(Roles = "school_admin")]
public class AdminAppearanceController : ControllerBase
{
    /// <summary>
    /// Palettes a school may choose. Defined here rather than fetched from the database because
    /// they are design decisions in styles.scss — adding one means writing its token block first.
    /// </summary>
    private static readonly string[] Themes = { "classic", "brand", "forest", "mist" };

    private readonly ISchoolRepository _schools;
    private readonly ICurrentSchool _school;

    public AdminAppearanceController(ISchoolRepository schools, ICurrentSchool school)
    {
        _schools = schools;
        _school = school;
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var school = await _schools.GetByIdAsync(_school.SchoolId, ct);
        return Ok(new { theme = school?.Theme ?? "classic", available = Themes });
    }

    /// <summary>
    /// Changes the palette for every portal at this school. Returns the stored value so the
    /// caller can apply it immediately rather than waiting for the next sign-in.
    /// </summary>
    [HttpPut]
    public async Task<IActionResult> Set([FromBody] SetThemeDto dto, CancellationToken ct)
    {
        var theme = dto.Theme?.Trim().ToLowerInvariant() ?? "";
        if (!Themes.Contains(theme))
            return BadRequest(new
            {
                error = "validation_error",
                message = $"'{dto.Theme}' is not a palette. Choose one of: {string.Join(", ", Themes)}.",
            });

        await _schools.SetThemeAsync(_school.SchoolId, theme, ct);
        return Ok(new { theme });
    }

    public class SetThemeDto
    {
        public string? Theme { get; set; }
    }
}
