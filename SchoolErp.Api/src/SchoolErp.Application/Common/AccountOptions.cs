namespace SchoolErp.Application.Common;

/// <summary>
/// Account provisioning knobs, bound from the "Accounts" config section in Program.cs.
/// </summary>
public class AccountOptions
{
    /// <summary>
    /// When set, every provisioned login (school admin, teacher, student) gets this password
    /// instead of a random one — a development convenience so test accounts are easy to sign in as.
    /// Leave null/empty in any shared or production environment to restore random passwords.
    /// </summary>
    public string? FixedPassword { get; set; }

    /// <summary>
    /// Where a newly registered person should go to sign in, put in their welcome email. Left
    /// empty the email simply omits the link rather than offering a broken one.
    /// </summary>
    public string? PortalUrl { get; set; }

    /// <summary>
    /// The reset page the password-reset email links to; the one-time token is appended as a
    /// <c>?token=</c> query parameter.
    ///
    /// Left empty it is derived from <see cref="PortalUrl"/> by swapping the last path segment
    /// for <c>reset-password</c>, which is where the Angular route lives — so a deployment that
    /// only ever sets PortalUrl still sends a link that works.
    /// </summary>
    public string? ResetPasswordUrl { get; set; }

    /// <summary>
    /// Whether to email credentials to the person as their account is created. On by default:
    /// an account nobody is told about is of no use. Turn it off for a bulk import into an
    /// environment whose addresses are not real.
    /// </summary>
    public bool SendWelcomeEmail { get; set; } = true;
}
