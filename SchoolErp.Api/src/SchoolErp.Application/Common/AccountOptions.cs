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
}
