namespace SchoolErp.Application.Interfaces.Services;

/// <summary>The staff id of the logged-in teacher (config for demo; JWT later).</summary>
public interface ICurrentTeacher
{
    long StaffId { get; }
    long SchoolId { get; }
}
