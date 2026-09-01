using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Api.Controllers.Admin;

[ApiController]
[Route("api/admin/dashboard")]
[Authorize(Roles = "school_admin")]
public class AdminDashboardController : ControllerBase
{
    private readonly IAdminDashboardService _service;
    public AdminDashboardController(IAdminDashboardService service) => _service = service;

    [HttpGet("stats")]
    public async Task<IActionResult> Stats(CancellationToken ct) => Ok(await _service.GetAsync(ct));
}
