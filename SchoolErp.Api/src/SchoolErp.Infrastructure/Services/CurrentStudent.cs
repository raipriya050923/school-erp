using Microsoft.Extensions.Configuration;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>Reads the logged-in student's id from config (Student:CurrentStudentId).</summary>
public class CurrentStudent : ICurrentStudent
{
    public long StudentId { get; }
    public long SchoolId { get; }

    public CurrentStudent(IConfiguration config)
    {
        StudentId = long.TryParse(config["Student:CurrentStudentId"], out var id) ? id : 1;
        SchoolId = long.TryParse(config["School:CurrentSchoolId"], out var school) ? school : 1;
    }
}
