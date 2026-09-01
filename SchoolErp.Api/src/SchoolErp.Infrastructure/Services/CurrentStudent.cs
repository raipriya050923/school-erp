using Microsoft.AspNetCore.Http;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Resolves the signed-in student from token claims. <c>student_id</c> is looked up from
/// <c>students.user_id</c> at login.
/// </summary>
public class CurrentStudent : ICurrentStudent
{
    private readonly IHttpContextAccessor _accessor;

    public CurrentStudent(IHttpContextAccessor accessor) => _accessor = accessor;

    public long StudentId => ClaimsAccessor.Require(_accessor, ErpClaims.StudentId, "student record");
    public long SchoolId => ClaimsAccessor.Require(_accessor, ErpClaims.SchoolId, "school id");
}
