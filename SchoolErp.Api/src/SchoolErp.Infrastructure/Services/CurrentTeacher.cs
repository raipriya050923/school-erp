using Microsoft.Extensions.Configuration;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>Reads the logged-in teacher's staff id from config (Teacher:CurrentStaffId).</summary>
public class CurrentTeacher : ICurrentTeacher
{
    public long StaffId { get; }
    public long SchoolId { get; }

    public CurrentTeacher(IConfiguration config)
    {
        StaffId = long.TryParse(config["Teacher:CurrentStaffId"], out var sid) ? sid : 1;
        SchoolId = long.TryParse(config["School:CurrentSchoolId"], out var school) ? school : 1;
    }
}
