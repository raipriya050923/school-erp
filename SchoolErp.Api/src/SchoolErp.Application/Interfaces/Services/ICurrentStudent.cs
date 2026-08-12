namespace SchoolErp.Application.Interfaces.Services;

/// <summary>The id of the logged-in student (config for demo; JWT later).</summary>
public interface ICurrentStudent
{
    long StudentId { get; }
    long SchoolId { get; }
}
