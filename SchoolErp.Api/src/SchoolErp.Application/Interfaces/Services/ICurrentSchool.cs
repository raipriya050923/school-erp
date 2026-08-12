namespace SchoolErp.Application.Interfaces.Services;

/// <summary>
/// Supplies the school id the admin request operates within. For the demo this is a
/// configured constant; with real auth it would come from the JWT/tenant claim.
/// </summary>
public interface ICurrentSchool
{
    long SchoolId { get; }
}
