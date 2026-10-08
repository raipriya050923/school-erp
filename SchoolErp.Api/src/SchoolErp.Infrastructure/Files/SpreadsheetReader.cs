using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Files;

/// <summary>
/// Adapts the static <see cref="Spreadsheet"/> helper to the interface the Application layer
/// depends on, so services stay testable and unaware of the zip-and-XML details.
/// </summary>
public class SpreadsheetReader : ISpreadsheetReader
{
    public IReadOnlyList<IReadOnlyList<string>> Read(Stream stream, string? fileName)
        => Spreadsheet.Read(stream, fileName);

    public byte[] Write(string sheetName, IEnumerable<IEnumerable<string>> rows)
        => Spreadsheet.Write(sheetName, rows);

    public DateTime? DateFromSerial(string value) => Spreadsheet.DateFromSerial(value);
}
