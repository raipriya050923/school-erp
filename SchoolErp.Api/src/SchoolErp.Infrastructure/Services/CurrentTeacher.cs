using Microsoft.AspNetCore.Http;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Resolves the signed-in teacher from token claims. <c>staff_id</c> is looked up from
/// <c>staff.user_id</c> at login, so a teacher account with no staff row cannot reach the portal.
/// </summary>
public class CurrentTeacher : ICurrentTeacher
{
    private readonly IHttpContextAccessor _accessor;

    public CurrentTeacher(IHttpContextAccessor accessor) => _accessor = accessor;

    public long StaffId => ClaimsAccessor.Require(_accessor, ErpClaims.StaffId, "staff record");
    public long SchoolId => ClaimsAccessor.Require(_accessor, ErpClaims.SchoolId, "school id");
}
