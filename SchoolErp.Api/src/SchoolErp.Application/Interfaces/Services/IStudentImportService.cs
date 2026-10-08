using SchoolErp.Application.DTOs.Admin;

namespace SchoolErp.Application.Interfaces.Services;

/// <summary>Bulk admission from a spreadsheet, and the sample file that documents its shape.</summary>
public interface IStudentImportService
{
    /// <summary>
    /// A workbook with the expected header row and a couple of filled example rows, pre-populated
    /// with the school's own classes and sections so the sample cannot suggest ones that
    /// do not exist.
    /// </summary>
    Task<(byte[] Content, string FileName)> TemplateAsync(CancellationToken ct = default);

    /// <summary>
    /// Reads an uploaded .xlsx or .csv and admits every valid row. Rows that fail validation are
    /// reported and skipped; the rest are still admitted.
    /// </summary>
    Task<StudentImportResultDto> ImportAsync(Stream file, string fileName, bool dryRun, CancellationToken ct = default);
}

/// <summary>
/// Reads tabular files. Implemented in Infrastructure so the Application layer does not have to
/// know whether the sheet came from a workbook or a CSV.
/// </summary>
public interface ISpreadsheetReader
{
    IReadOnlyList<IReadOnlyList<string>> Read(Stream stream, string? fileName);
    byte[] Write(string sheetName, IEnumerable<IEnumerable<string>> rows);
    /// <summary>An Excel date serial as a date, or null when the text is not one.</summary>
    DateTime? DateFromSerial(string value);
}
