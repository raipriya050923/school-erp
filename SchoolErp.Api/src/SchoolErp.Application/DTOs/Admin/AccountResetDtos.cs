namespace SchoolErp.Application.DTOs.Admin;

/// <summary>
/// A password reset ordered by a school administrator.
///
/// <paramref name="NewPassword"/> is optional and usually left empty: the server then invents a
/// strong one, which is the safer default because an administrator choosing passwords by hand
/// ends up reusing one across a whole class. It is offered at all because the common case is an
/// administrator reading the new password down a telephone to a parent, and a generated string
/// of symbols does not survive that trip.
/// </summary>
public class ResetAccountPasswordDto
{
    public string? NewPassword { get; set; }
}

/// <summary>
/// Whether a person has a portal login at all, so the screen can offer the right action — a
/// reset for someone who has one, nothing for someone who does not.
/// </summary>
public record LoginSummaryDto(bool HasLogin, string? Username, string? LastPasswordChangeNote);
