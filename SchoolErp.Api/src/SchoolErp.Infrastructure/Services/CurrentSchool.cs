using Microsoft.Extensions.Configuration;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>Reads the active school id from configuration (School:CurrentSchoolId).</summary>
public class CurrentSchool : ICurrentSchool
{
    public long SchoolId { get; }

    public CurrentSchool(IConfiguration config)
        => SchoolId = long.TryParse(config["School:CurrentSchoolId"], out var id) ? id : 1;
}
