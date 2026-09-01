using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Auth;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services.Auth;

/// <inheritdoc />
public class ProfileService : IProfileService
{
    private readonly ICurrentUser _current;
    private readonly IUserRepository _users;
    private readonly ISchoolRepository _schools;
    private readonly ITeacherRepository _teachers;
    private readonly IStudentRepository _students;
    private readonly ISubscriptionRepository _subscriptions;

    public ProfileService(ICurrentUser current, IUserRepository users, ISchoolRepository schools,
        ITeacherRepository teachers, IStudentRepository students, ISubscriptionRepository subscriptions)
    {
        _current = current;
        _users = users;
        _schools = schools;
        _teachers = teachers;
        _students = students;
        _subscriptions = subscriptions;
    }

    public async Task<MyProfileDto> GetMineAsync(CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(_current.UserId, ct)
                   ?? throw new NotFoundException("Your account no longer exists.");

        var school = user.SchoolId is { } sid ? await _schools.GetByIdAsync(sid, ct) : null;
        var details = new List<ProfileDetailDto>();

        switch (user.UserType)
        {
            case "school_admin":
                if (school is not null)
                {
                    details.Add(new("School code", school.SchoolCode));
                    details.Add(new("Portal", $"{school.Subdomain}.edunexus.io"));
                    var sub = await _subscriptions.GetCurrentBySchoolAsync(school.Id, ct);
                    details.Add(new("Plan", sub?.PlanName ?? "No plan"));
                    if (sub is not null)
                        details.Add(new("Subscription", $"{Title(sub.Status)} until {sub.EndDate:d MMM yyyy}"));
                }
                break;

            case "teacher":
            case "staff":
                // The portal keys off the staff row, so show that record rather than the login.
                if (user.SchoolId is { } tsid && await _users.GetStaffIdAsync(user.Id, ct) is { } staffId
                    && await _teachers.GetByIdAsync(tsid, staffId, ct) is { } staff)
                {
                    details.Add(new("Employee code", staff.EmployeeCode));
                    details.Add(new("Subject", staff.Specialization));
                    details.Add(new("Qualification", staff.Qualification));
                    details.Add(new("Joined", staff.JoiningDate?.ToString("d MMM yyyy")));
                    details.Add(new("Status", Title(staff.Status)));
                }
                else
                {
                    details.Add(new("Staff record", "Not linked — contact your administrator"));
                }
                break;

            case "student":
                if (user.SchoolId is { } ssid && await _users.GetStudentIdAsync(user.Id, ct) is { } studentId
                    && await _students.GetByIdAsync(ssid, studentId, ct) is { } student)
                {
                    details.Add(new("Admission no", student.AdmissionNo));
                    details.Add(new("Class", Join(student.ClassName, student.SectionName)));
                    details.Add(new("Roll no", student.RollNo));
                    details.Add(new("Guardian", student.GuardianName));
                    details.Add(new("Guardian phone", student.GuardianPhone));
                    details.Add(new("Admitted", student.AdmissionDate?.ToString("d MMM yyyy")));
                }
                else
                {
                    details.Add(new("Student record", "Not linked — contact your administrator"));
                }
                break;

            case "super_admin":
                details.Add(new("Scope", "All schools on the platform"));
                break;
        }

        var (role, title) = MapRole(user.UserType);
        return new MyProfileDto(user.Id, user.Username, user.FullName, user.Email, user.Phone,
            role, title, user.SchoolId, school?.Name, details);
    }

    private static string Join(string? a, string? b) =>
        string.IsNullOrWhiteSpace(b) ? (a ?? "—") : $"{a}-{b}";

    private static string Title(string s) =>
        string.IsNullOrEmpty(s) ? "" : char.ToUpperInvariant(s[0]) + s[1..].Replace('_', ' ');

    private static (string Role, string Title) MapRole(string userType) => userType switch
    {
        "super_admin" => ("super_admin", "Platform Owner"),
        "school_admin" => ("school_admin", "Administrator"),
        "teacher" => ("teacher", "Teacher"),
        "student" => ("student", "Student"),
        _ => (userType, Title(userType)),
    };
}
