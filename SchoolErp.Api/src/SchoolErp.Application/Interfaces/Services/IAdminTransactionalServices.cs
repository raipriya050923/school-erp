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
    Task<long> AddPaperAsync(SaveExamPaperDto dto, CancellationToken ct = default);
    Task DeletePaperAsync(long paperId, CancellationToken ct = default);
}

public interface IAdminFeeService
{
    Task<IReadOnlyList<FeeInvoiceDto>> ListAsync(string? status, CancellationToken ct = default);
    Task<FeeSummaryDto> SummaryAsync(CancellationToken ct = default);
    Task RecordPaymentAsync(long invoiceId, RecordFeePaymentDto dto, CancellationToken ct = default);
    Task<int> GenerateAsync(GenerateInvoicesDto dto, CancellationToken ct = default);
}