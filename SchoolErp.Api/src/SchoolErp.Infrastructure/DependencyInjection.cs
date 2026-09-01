using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Infrastructure.Persistence;
using SchoolErp.Infrastructure.Repositories;
using SchoolErp.Infrastructure.Services;

namespace SchoolErp.Infrastructure;

/// <summary>Registers Infrastructure services (ADO.NET repositories, connection factory).</summary>
public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        var connectionString = config.GetConnectionString("MySql")
            ?? throw new InvalidOperationException("Connection string 'MySql' is not configured.");

        services.AddSingleton<IDbConnectionFactory>(_ => new MySqlConnectionFactory(connectionString));

        // The Current* services read the caller's claims, so they need the ambient request.
        services.AddHttpContextAccessor();

        services.AddScoped<ISchoolRepository, SchoolRepository>();
        services.AddScoped<IPlanRepository, PlanRepository>();
        services.AddScoped<ISubscriptionRepository, SubscriptionRepository>();
        services.AddScoped<IBillingRepository, BillingRepository>();
        services.AddScoped<ITicketRepository, TicketRepository>();
        services.AddScoped<IGeographyRepository, GeographyRepository>();

        // School Admin
        services.AddScoped<IStudentRepository, StudentRepository>();
        services.AddScoped<ITeacherRepository, TeacherRepository>();
        services.AddScoped<IClassRepository, ClassRepository>();
        services.AddScoped<INoticeRepository, NoticeRepository>();
        services.AddScoped<ICurriculumRepository, CurriculumRepository>();
        services.AddScoped<IAcademicYearRepository, AcademicYearRepository>();
        services.AddScoped<ICurrentSchool, CurrentSchool>();
        services.AddScoped<ICurrentUser, CurrentUser>();

        // Teacher portal
        services.AddScoped<ITeacherPortalRepository, TeacherPortalRepository>();
        services.AddScoped<ICurrentTeacher, CurrentTeacher>();

        // Transactional (shared by teacher + admin)
        services.AddScoped<IAttendanceRepository, AttendanceRepository>();
        services.AddScoped<IExamRepository, ExamRepository>();
        services.AddScoped<IExamResultRepository, ExamResultRepository>();
        services.AddScoped<ISubjectRepository, SubjectRepository>();
        services.AddScoped<IStaffAttendanceRepository, StaffAttendanceRepository>();
        services.AddScoped<ILeaveRepository, LeaveRepository>();
        services.AddScoped<ITimetableRepository, TimetableRepository>();
        services.AddScoped<IFeeRepository, FeeRepository>();
        services.AddScoped<IFeeStructureRepository, FeeStructureRepository>();

        // Student portal
        services.AddScoped<IStudentPortalRepository, StudentPortalRepository>();
        services.AddScoped<ICurrentStudent, CurrentStudent>();

        // Auth
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddSingleton<IPasswordHasher, BcryptPasswordHasher>();
        services.AddSingleton<ITokenService, JwtTokenService>();

        services.AddScoped<INotificationSender, LoggingNotificationSender>();
        services.AddScoped<INotificationRepository, NotificationRepository>();

        return services;
    }
}
