using Microsoft.Extensions.DependencyInjection;
using SchoolErp.Application.Interfaces.Services;
using SchoolErp.Application.Services;
using SchoolErp.Application.Services.Admin;

namespace SchoolErp.Application;

/// <summary>Registers Application-layer services. Called from the API's Program.cs.</summary>
public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        // Super Admin
        services.AddScoped<ISchoolService, SchoolService>();
        services.AddScoped<IPlanService, PlanService>();
        services.AddScoped<ISubscriptionService, SubscriptionService>();
        services.AddScoped<IBillingService, BillingService>();
        services.AddScoped<ITicketService, TicketService>();
        services.AddScoped<IDashboardService, DashboardService>();
        services.AddScoped<Interfaces.Services.IGeographyService, Services.GeographyService>();

        // School Admin
        services.AddScoped<IAdminDashboardService, AdminDashboardService>();
        // Plan entitlements: seats, expiry and the login gate. Registered once and
        // shared, so login, admissions and the dashboard warning cannot disagree.
        services.AddScoped<ISubscriptionGuard, SubscriptionGuard>();
        services.AddScoped<IStudentService, StudentService>();
        services.AddScoped<IParentAccountService, ParentAccountService>();
        services.AddScoped<ITeacherService, TeacherService>();
        services.AddScoped<IClassService, ClassService>();
        services.AddScoped<INoticeService, NoticeService>();
        services.AddScoped<ICurriculumService, CurriculumService>();
        services.AddScoped<Interfaces.Services.ITimetableAdminService, Services.Admin.TimetableAdminService>();
        services.AddScoped<IAcademicYearService, AcademicYearService>();
        services.AddScoped<Interfaces.Services.ISchoolClock, Services.SchoolClock>();
        services.AddScoped<Interfaces.Services.ISubjectService, Services.Admin.SubjectService>();
        services.AddScoped<Interfaces.Services.IStaffAttendanceService, Services.Admin.StaffAttendanceService>();
        services.AddScoped<Interfaces.Services.ILeaveService, Services.Admin.LeaveService>();

        // Teacher portal
        services.AddScoped<Interfaces.Services.ITeacherPortalService, Services.Teacher.TeacherPortalService>();

        // Admin transactional
        services.AddScoped<Interfaces.Services.IAdminAttendanceService, Services.Admin.AdminAttendanceService>();
        services.AddScoped<Interfaces.Services.IAdminExamService, Services.Admin.AdminExamService>();
        services.AddScoped<Interfaces.Services.IAdminFeeService, Services.Admin.AdminFeeService>();
        services.AddScoped<Interfaces.Services.IFeeStructureService, Services.Admin.FeeStructureService>();
        services.AddScoped<Interfaces.Services.ITransportService, Services.Admin.TransportService>();
        services.AddScoped<Interfaces.Services.IAccountResetService, Services.Admin.AccountResetService>();
        // Shared by both portals so the office and the family print the same document.
        services.AddScoped<Services.FeeReceiptBuilder>();
        services.AddScoped<Interfaces.Services.IStudentImportService, Services.Admin.StudentImportService>();

        // Student portal
        services.AddScoped<Interfaces.Services.IStudentPortalService, Services.StudentPortal.StudentPortalService>();

        // Auth
        services.AddScoped<Interfaces.Services.IAuthService, Services.Auth.AuthService>();
        services.AddScoped<Interfaces.Services.IAccountProvisioner, Services.Auth.AccountProvisioner>();
        services.AddScoped<Interfaces.Services.IProfileService, Services.Auth.ProfileService>();

        // Notification bell (read by every portal, written by the services above)
        services.AddScoped<Interfaces.Services.INotificationCenter, Services.NotificationCenterService>();
        return services;
    }
}
