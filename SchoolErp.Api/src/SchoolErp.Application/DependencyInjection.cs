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

        // School Admin
        services.AddScoped<IAdminDashboardService, AdminDashboardService>();
        services.AddScoped<IStudentService, StudentService>();
        services.AddScoped<ITeacherService, TeacherService>();
        services.AddScoped<IClassService, ClassService>();
        services.AddScoped<INoticeService, NoticeService>();

        // Teacher portal
        services.AddScoped<Interfaces.Services.ITeacherPortalService, Services.Teacher.TeacherPortalService>();

        // Admin transactional
        services.AddScoped<Interfaces.Services.IAdminAttendanceService, Services.Admin.AdminAttendanceService>();
        services.AddScoped<Interfaces.Services.IAdminExamService, Services.Admin.AdminExamService>();
        services.AddScoped<Interfaces.Services.IAdminFeeService, Services.Admin.AdminFeeService>();

        // Student portal
        services.AddScoped<Interfaces.Services.IStudentPortalService, Services.StudentPortal.StudentPortalService>();

        // Auth
        services.AddScoped<Interfaces.Services.IAuthService, Services.Auth.AuthService>();
        return services;
    }
}
