using Microsoft.AspNetCore.Http;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <inheritdoc />
public class CurrentUser : ICurrentUser
{
    private readonly IHttpContextAccessor _accessor;

    public CurrentUser(IHttpContextAccessor accessor) => _accessor = accessor;

    public long UserId => ClaimsAccessor.Require(_accessor, ErpClaims.UserId, "signed-in user");

    /// <summary>Null for platform staff, who are not scoped to a tenant.</summary>
    public long? SchoolId => ClaimsAccessor.TryRead(_accessor, ErpClaims.SchoolId);
}
