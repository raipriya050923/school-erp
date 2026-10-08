using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Auth;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>
/// Lets a school administrator put a teacher, student or parent back into their own portal after
/// a forgotten password. Self-service reset exists, but it needs a working email address on the
/// account, and most students here have none — so without this the office has no answer at all.
/// </summary>
public interface IAccountResetService
{
    /// <summary>Whether this teacher has a login, for deciding what the screen offers.</summary>
    Task<LoginSummaryDto> TeacherLoginAsync(long staffId, CancellationToken ct = default);
    Task<LoginSummaryDto> StudentLoginAsync(long studentId, CancellationToken ct = default);

    /// <summary>
    /// Issues a new password for the teacher's login and returns it once. The account is flagged
    /// to force a change at next sign-in: an administrator has read this password, so it gets the
    /// holder in but is not yet their secret.
    /// </summary>
    Task<GeneratedCredentialsDto> ResetTeacherAsync(long staffId, ResetAccountPasswordDto dto, CancellationToken ct = default);
    Task<GeneratedCredentialsDto> ResetStudentAsync(long studentId, ResetAccountPasswordDto dto, CancellationToken ct = default);
    /// <summary>The guardian login attached to a student — the account a parent signs in with.</summary>
    Task<GeneratedCredentialsDto> ResetParentAsync(long studentId, ResetAccountPasswordDto dto, CancellationToken ct = default);
}
