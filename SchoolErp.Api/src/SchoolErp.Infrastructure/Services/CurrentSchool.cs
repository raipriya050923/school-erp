using Microsoft.AspNetCore.Http;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Resolves the tenant from the caller's signed <c>school_id</c> claim. The value is set at
/// login from the user's own row and signed into the token, so it cannot be altered by the client.
/// </summary>
public class CurrentSchool : ICurrentSchool
{
    private readonly IHttpContextAccessor _accessor;

    public CurrentSchool(IHttpContextAccessor accessor) => _accessor = accessor;

    public long SchoolId => ClaimsAccessor.Require(_accessor, ErpClaims.SchoolId, "school id");
}
