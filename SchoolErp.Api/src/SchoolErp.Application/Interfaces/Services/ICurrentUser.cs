namespace SchoolErp.Application.Interfaces.Services;

/// <summary>
/// The signed-in account behind the current request, read from the validated token.
/// Unlike <see cref="ICurrentSchool"/> this never throws on a missing tenant: platform staff
/// (super_admin) legitimately have no school, so <see cref="SchoolId"/> is null for them.
/// </summary>
public interface ICurrentUser
{
    long UserId { get; }
    long? SchoolId { get; }
}
