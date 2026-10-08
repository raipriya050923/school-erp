namespace SchoolErp.Application.DTOs.Admin;

/// <summary>
/// What became of one row of an uploaded sheet. Rows are reported individually rather than the
/// whole file failing on the first bad one: a hundred-row admission list with two typos should
/// admit ninety-eight students and tell the admin about the two.
/// </summary>
public record StudentImportRowDto(
    /// <summary>Row number as it appears in the spreadsheet, header included, so it can be found.</summary>
    int Row,
    string Name,
    /// <summary>created | skipped | failed</summary>
    string Status,
    string? Message,
    string? AdmissionNo,
    string? RollNo,
    /// <summary>
    /// The login minted for the student. The password exists only in this response — it is stored
    /// as a hash and cannot be retrieved again, so the admin has to save it now.
    /// </summary>
    string? Username,
    string? TemporaryPassword);

public record StudentImportResultDto(
    int TotalRows, int Created, int Skipped, int Failed,
    IReadOnlyList<StudentImportRowDto> Rows);

/// <summary>
/// A parsed row before it is admitted. Kept separate from <see cref="SaveStudentDto"/> so a
/// sheet can carry a class and section by name without the geography ids the form supplies.
/// </summary>
public class StudentImportRow
{
    public int RowNumber { get; set; }
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public string ClassName { get; set; } = "";
    public string SectionName { get; set; } = "";
    public string Gender { get; set; } = "";
    public string Dob { get; set; } = "";
    public string BloodGroup { get; set; } = "";
    public string GuardianName { get; set; } = "";
    public string GuardianPhone { get; set; } = "";
    public string Email { get; set; } = "";
    public string Address { get; set; } = "";
    public string City { get; set; } = "";
    public string State { get; set; } = "";
    public string Pincode { get; set; } = "";
    public string PreviousSchool { get; set; } = "";
    public string TcNo { get; set; } = "";
}
