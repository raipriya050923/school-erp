namespace SchoolErp.Application.Common;

/// <summary>
/// Custom claim names carried by the access token. Tenant scoping reads <see cref="SchoolId"/>
/// from here, so these must stay in sync between the token issuer and the Current* services.
/// </summary>
public static class ErpClaims
{
    public const string UserId = "uid";
    public const string SchoolId = "school_id";
    public const string StaffId = "staff_id";
    public const string StudentId = "student_id";
    public const string UserType = "user_type";
    /// <summary>
    /// Present and "1" while the holder is still on a password an administrator issued. Carried
    /// in the token so enforcement happens at the API, not only in whichever client is asking.
    /// </summary>
    public const string MustChangePassword = "pwd_change";
}
