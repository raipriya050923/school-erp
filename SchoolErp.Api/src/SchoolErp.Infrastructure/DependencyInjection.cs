using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SchoolErp.Application.Common;
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
        services.AddScoped<IGuardianRepository, GuardianRepository>();
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
        services.AddSingleton<Application.Interfaces.Services.ISpreadsheetReader, Files.SpreadsheetReader>();
        services.AddScoped<ISubjectRepository, SubjectRepository>();
        services.AddScoped<IStaffAttendanceRepository, StaffAttendanceRepository>();
        services.AddScoped<ILeaveRepository, LeaveRepository>();
        services.AddScoped<IMessageTemplateRepository, MessageTemplateRepository>();
        services.AddScoped<ITimetableRepository, TimetableRepository>();
        services.AddScoped<IFeeRepository, FeeRepository>();
        services.AddScoped<IFeeSubmissionRepository, FeeSubmissionRepository>();
        services.AddScoped<IFeeStructureRepository, FeeStructureRepository>();
        services.AddScoped<ITransportRepository, TransportRepository>();

        // Student portal
        services.AddScoped<IStudentPortalRepository, StudentPortalRepository>();
        services.AddScoped<ICurrentStudent, CurrentStudent>();

        // Auth
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddSingleton<IPasswordHasher, BcryptPasswordHasher>();
        services.AddSingleton<ITokenService, JwtTokenService>();

        // Real mail once an SMTP host is configured, the logging stub otherwise — so a developer
        // with no mail server still gets a running API and sees every message in the console.
        //
        // Bound from HostingerEmailSettings and nothing else. There is deliberately no fallback
        // purpose: that mailbox never authenticated, so every welcome email and password reset
        // sent through it failed, and a silent fall-back to it would quietly resume failing the
        // moment this section were renamed. With no Hostinger section the stub takes over and
        // messages go to the log — visibly nowhere, rather than invisibly to a dead mailbox.
        var email = config.GetSection("HostingerEmailSettings").Get<EmailOptions>()
                    ?? new EmailOptions();
        services.AddSingleton(email);
        // The console's row wins over the file once it carries a host; the provider caches it
        // and is invalidated on save. Registered unconditionally, so a deployment that started
        // with no mail configuration can be given one without a restart.
        services.AddSingleton<IEmailSettingsProvider, EmailSettingsProvider>();
        services.AddScoped<IEmailSettingsRepository, EmailSettingsRepository>();
        // Always the SMTP sender now. Whether mail can actually leave is a property of the
        // settings at send time rather than of the file at startup: a deployment that fills
        // the mailbox in through the console must not need a restart to start using it. The
        // sender resolves its settings per message and logs instead of sending when it finds
        // no host, which is what the stub used to do.
        services.AddScoped<INotificationSender, SmtpEmailSender>();
        // The same provider reached through its own typed options, for the endpoints under
        // /api/super-admin/email/hostinger that exercise it directly. Not registered as
        // INotificationSender because the default above already is one.
        var hostinger = config.GetSection("HostingerEmailSettings").Get<HostingerEmailOptions>()
                        ?? new HostingerEmailOptions();
        services.AddSingleton(hostinger);
        services.AddScoped<HostingerEmailSender>();

        services.AddScoped<INotificationRepository, NotificationRepository>();

        return services;
    }
}
