namespace SchoolErp.Application.DTOs.Dashboard;

public record DashboardStatsDto(
    int TotalSchools,
    int ActiveSubscriptions,
    int TrialSubscriptions,
    decimal MonthlyRecurringRevenue,
    int OpenTickets);
