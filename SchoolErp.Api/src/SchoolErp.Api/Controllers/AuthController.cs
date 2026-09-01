using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/auth")]
[AllowAnonymous]   // this is where callers get a token, so it cannot require one
public class AuthController : ControllerBase
{
    private readonly IAuthService _service;
    private readonly IProfileService _profiles;

    public AuthController(IAuthService service, IProfileService profiles)
    {
        _service = service;
        _profiles = profiles;
    }

    /// <summary>The signed-in user's own profile — works for every role.</summary>
    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me(CancellationToken ct) => Ok(await _profiles.GetMineAsync(ct));

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto, CancellationToken ct)
        => Ok(await _service.LoginAsync(dto, ct));

    /// <summary>Requires a session: the current password is verified, but only signed-in users may call it.</summary>
    [Authorize]
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto, CancellationToken ct)
    {
        await _service.ChangePasswordAsync(dto, ct);
        return NoContent();
    }

    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordDto dto, CancellationToken ct)
        => Ok(await _service.ForgotPasswordAsync(dto, ct));

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordDto dto, CancellationToken ct)
    {
        await _service.ResetPasswordAsync(dto, ct);
        return NoContent();
    }
}
