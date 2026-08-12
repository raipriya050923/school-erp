using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _service;
    public AuthController(IAuthService service) => _service = service;

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto, CancellationToken ct)
        => Ok(await _service.LoginAsync(dto, ct));

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
