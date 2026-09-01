using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.DTOs.Transactional;

namespace SchoolErp.Application.Interfaces.Services;

public interface IAdminAttendanceService
{
    Task<IReadOnlyList<AttendanceRowDto>> GetAsync(string className, string sectionName, DateTime date, CancellationToken ct = default);
    Task SaveAsync(SaveAttendanceDto dto, CancellationToken ct = default);
    Task<AttendanceReportDto> ReportAsync(long studentId, DateTime from, DateTime to, CancellationToken ct = default);
}

public interface IAdminExamService
{
    Task<IReadOnlyList<ExamDto>> ListAsync(CancellationToken ct = default);
    Task<long> CreateExamAsync(CreateExamDto dto, CancellationToken ct = default);
    Task UpdateExamAsync(long id, CreateExamDto dto, CancellationToken ct = default);
    /// <summary>Deletes the exam along with its papers and recorded marks.</summary>
    Task DeleteExamAsync(long id, CancellationToken ct = default);
    /// <summary>
    /// Schedules a paper for one class or several. Classes already carrying the subject are
    /// reported back rather than treated as an error.
    /// </summary>
    Task<AddPapersResultDto> AddPaperAsync(SaveExamPaperDto dto, CancellationToken ct = default);
    Task DeletePaperAsync(long paperId, CancellationToken ct = default);
    /// <summary>Cancels an exam, or reinstates a cancelled one back onto its dates.</summary>
    Task SetStatusAsync(long examId, string status, CancellationToken ct = default);
    /// <summary>Every section that sat the exam, and whether its class teacher has signed it off.</summary>
    Task<IReadOnlyList<ExamApprovalDto>> ApprovalsAsync(long examId, CancellationToken ct = default);
}

public interface IStaffAttendanceService
{
    Task<IReadOnlyList<StaffAttendanceRowDto>> GetAsync(DateTime date, CancellationToken ct = default);
    Task SaveAsync(SaveStaffAttendanceDto dto, CancellationToken ct = default);
    Task<StaffAttendanceSummaryDto> SummaryAsync(DateTime from, DateTime to, CancellationToken ct = default);
}

public interface ILeaveService
{
    Task<IReadOnlyList<LeaveTypeDto>> TypesAsync(CancellationToken ct = default);
    /// <summary>Every request at the school — the admin's queue.</summary>
    Task<IReadOnlyList<LeaveApplicationDto>> ListAsync(string? status, CancellationToken ct = default);
    /// <summary>Only the signed-in user's own requests.</summary>
    Task<IReadOnlyList<LeaveApplicationDto>> MineAsync(CancellationToken ct = default);
    Task<long> ApplyAsync(ApplyLeaveDto dto, CancellationToken ct = default);
    /// <summary>Admin records leave for a staff member; optionally approved on the spot.</summary>
    Task<long> ApplyForStaffAsync(ApplyLeaveForStaffDto dto, CancellationToken ct = default);
    Task<long> CreateTypeAsync(SaveLeaveTypeDto dto, CancellationToken ct = default);
    Task ReviewAsync(long id, ReviewLeaveDto dto, CancellationToken ct = default);
}

public interface ISubjectService
{
    Task<IReadOnlyList<SubjectDto>> ListAsync(CancellationToken ct = default);
    /// <summary>Active names only — what the exam Add Subject dropdown offers.</summary>
    Task<IReadOnlyList<string>> ActiveNamesAsync(CancellationToken ct = default);
    Task<long> CreateAsync(SaveSubjectDto dto, CancellationToken ct = default);
    Task UpdateAsync(long id, SaveSubjectDto dto, CancellationToken ct = default);
    Task SetActiveAsync(long id, bool isActive, CancellationToken ct = default);
}

public interface IAdminFeeService
{
    Task<IReadOnlyList<FeeInvoiceDto>> ListAsync(string? status, CancellationToken ct = default);
    Task<FeeSummaryDto> SummaryAsync(CancellationToken ct = default);
    /// <summary>The head-by-head breakdown behind one invoice total.</summary>
    Task<IReadOnlyList<FeeInvoiceLineDto>> LinesAsync(long invoiceId, CancellationToken ct = default);
    Task RecordPaymentAsync(long invoiceId, RecordFeePaymentDto dto, CancellationToken ct = default);
    Task<GenerateInvoicesResultDto> GenerateAsync(GenerateInvoicesDto dto, CancellationToken ct = default);
}