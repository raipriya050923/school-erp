using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Auth;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>Parent logins, issued by the school office against a student.</summary>
public interface IParentAccountService
{
    /// <summary>The guardian on a student and whether they can sign in yet.</summary>
    Task<ParentAccountDto?> GetAsync(long studentId, CancellationToken ct = default);

    /// <summary>
    /// Issues a login for the student's parent, creating the guardian record if
    /// the school never captured one. Returns the credentials, which exist only
    /// in this response.
    /// </summary>
    Task<GeneratedCredentialsDto> CreateLoginAsync(long studentId, CreateParentLoginDto dto, CancellationToken ct = default);
}
