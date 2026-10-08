using System.Globalization;
using SchoolErp.Application.Common;
using SchoolErp.Application.DTOs.Admin;
using SchoolErp.Application.Interfaces.Persistence;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Application.Services.Admin;

public class StudentImportService : IStudentImportService
{
    /// <summary>
    /// The columns the sheet is expected to carry, in order. Matching is by header name rather
    /// than position, so an admin may reorder or add columns of their own; these are the names
    /// looked for, lower-cased and stripped of spaces and punctuation.
    /// </summary>
    private static readonly (string Key, string Header, bool Required)[] Columns =
    {
        ("firstname",      "First Name",      true),
        ("lastname",       "Last Name",       true),
        ("class",          "Class",           true),
        ("section",        "Section",         true),
        ("gender",         "Gender",          true),
        ("dateofbirth",    "Date of Birth",   false),
        ("bloodgroup",     "Blood Group",     false),
        ("guardianname",   "Guardian Name",   true),
        ("guardianphone",  "Guardian Phone",  true),
        ("email",          "Email",           false),
        ("address",        "Address",         false),
        ("city",           "City",            false),
        ("state",          "State",           false),
        ("pincode",        "Pincode",         false),
        ("previousschool", "Previous School", false),
        ("tcno",           "TC No",           false),
    };

    /// <summary>
    /// A ceiling on one upload. Each row provisions a login and writes several rows, so a
    /// mistakenly pasted ten-thousand-row sheet would hold the request open for minutes.
    /// </summary>
    private const int MaxRows = 500;

    private static readonly string[] Genders = { "male", "female", "other" };

    private readonly IStudentService _students;
    private readonly IClassRepository _classes;
    private readonly IStudentRepository _repo;
    private readonly ISpreadsheetReader _sheets;
    private readonly ICurrentSchool _school;

    public StudentImportService(IStudentService students, IClassRepository classes,
        IStudentRepository repo, ISpreadsheetReader sheets, ICurrentSchool school)
    {
        _students = students;
        _classes = classes;
        _repo = repo;
        _sheets = sheets;
        _school = school;
    }

    /* ============================ the sample file ============================ */

    public async Task<(byte[] Content, string FileName)> TemplateAsync(CancellationToken ct = default)
    {
        var classes = await _classes.GetAllWithSectionsAsync(_school.SchoolId, ct);
        // Examples use the school's own first two class/section pairs. A sample naming classes
        // that do not exist would fail on import, which is a poor first impression of the feature.
        var pairs = classes
            .SelectMany(c => c.Sections.Select(s => (Class: c.Name, Section: s.Name)))
            .Take(2).ToList();
        while (pairs.Count < 2) pairs.Add(("", ""));

        var rows = new List<IEnumerable<string>>
        {
            Columns.Select(c => c.Required ? c.Header + " *" : c.Header),
            new[]
            {
                "Aarav", "Sharma", pairs[0].Class, pairs[0].Section, "male", "2015-04-12", "O+",
                "Rohit Sharma", "9876543210", "", "12 Station Road", "", "", "560001", "", "",
            },
            new[]
            {
                "Diya", "Verma", pairs[1].Class, pairs[1].Section, "female", "2015-09-30", "",
                "Sunita Verma", "9812345678", "diya@example.com", "", "", "", "", "Little Stars School", "TC/2025/0417",
            },
        };
        return (_sheets.Write("Students", rows), "student-import-template.xlsx");
    }

    /* ============================ the import ============================ */

    public async Task<StudentImportResultDto> ImportAsync(Stream file, string fileName, bool dryRun, CancellationToken ct = default)
    {
        IReadOnlyList<IReadOnlyList<string>> grid;
        try
        {
            grid = _sheets.Read(file, fileName);
        }
        catch (Exception ex)
        {
            throw new ValidationException(
                $"That file could not be read as a spreadsheet. Save it as .xlsx or .csv and try again. ({ex.Message})");
        }

        // Leading blank rows are common in hand-edited sheets, so the header is the first row
        // carrying anything rather than row 1 by decree.
        var headerIndex = grid.ToList().FindIndex(r => r.Any(c => !string.IsNullOrWhiteSpace(c)));
        if (headerIndex < 0) throw new ValidationException("That file is empty.");

        var map = MapColumns(grid[headerIndex]);
        var missing = Columns.Where(c => c.Required && !map.ContainsKey(c.Key)).Select(c => c.Header).ToList();
        if (missing.Count > 0)
            throw new ValidationException(
                $"These columns are missing from the sheet: {string.Join(", ", missing)}. " +
                "Download the sample file to see the expected headers.");

        var body = grid.Skip(headerIndex + 1)
            .Select((cells, i) => (Cells: cells, RowNumber: headerIndex + 2 + i))
            .Where(r => r.Cells.Any(c => !string.IsNullOrWhiteSpace(c)))
            .ToList();

        if (body.Count > MaxRows)
            throw new ValidationException(
                $"That sheet has {body.Count} rows. Import at most {MaxRows} at a time so a mistake stays easy to undo.");

        // Loaded once: checking every row against the database would be a query per row, and the
        // class list cannot change mid-import.
        var sections = (await _classes.GetAllWithSectionsAsync(_school.SchoolId, ct))
            .SelectMany(c => c.Sections.Select(s => (c.Name, Section: s.Name)))
            .ToList();

        var results = new List<StudentImportRowDto>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        int created = 0, skipped = 0, failed = 0;

        foreach (var (cells, rowNumber) in body)
        {
            var row = ReadRow(cells, map, rowNumber);
            var name = $"{row.FirstName} {row.LastName}".Trim();

            var problem = Validate(row, sections);
            if (problem is null)
            {
                // Two rows for the same person in one sheet is a copy-paste slip, not two
                // admissions. Caught here because the database has no such constraint.
                var key = $"{name}|{row.ClassName}|{row.SectionName}|{row.GuardianPhone}";
                if (!seen.Add(key)) problem = "This row repeats an earlier row in the same file.";
            }
            if (problem is null && await _repo.ExistsInSectionAsync(_school.SchoolId, row.FirstName, row.LastName, row.ClassName, row.SectionName, ct))
                problem = $"{name} is already admitted to {row.ClassName}-{row.SectionName}.";

            if (problem is not null)
            {
                failed++;
                results.Add(new StudentImportRowDto(rowNumber, name, "failed", problem, null, null, null, null));
                continue;
            }

            if (dryRun)
            {
                skipped++;
                results.Add(new StudentImportRowDto(rowNumber, name, "skipped", "Looks good — not imported (check only).", null, null, null, null));
                continue;
            }

            try
            {
                // Straight through the ordinary admission path, so an imported student gets the
                // same admission number, roll number and login an admin-typed one would.
                var result = await _students.CreateAsync(ToSaveDto(row), ct);
                created++;
                results.Add(new StudentImportRowDto(rowNumber, name, "created", null,
                    result.AdmissionNo, result.RollNo,
                    result.Credentials.Username, result.Credentials.TemporaryPassword));
            }
            catch (Exception ex)
            {
                failed++;
                results.Add(new StudentImportRowDto(rowNumber, name, "failed", ex.Message, null, null, null, null));
            }
        }

        return new StudentImportResultDto(body.Count, created, skipped, failed, results);
    }

    /* ============================ parsing ============================ */

    /// <summary>Header name to column index, matched loosely so spacing and case do not matter.</summary>
    private static Dictionary<string, int> MapColumns(IReadOnlyList<string> header)
    {
        var map = new Dictionary<string, int>();
        for (var i = 0; i < header.Count; i++)
        {
            var key = Normalise(header[i]);
            if (key.Length == 0) continue;
            var column = Columns.FirstOrDefault(c => c.Key == key
                || Normalise(c.Header) == key
                // "First Name *" from the sample, and "DOB" as a common shorthand.
                || key.TrimEnd('*') == c.Key
                || (c.Key == "dateofbirth" && key is "dob"));
            if (column.Key is not null && !map.ContainsKey(column.Key)) map[column.Key] = i;
        }
        return map;
    }

    private static string Normalise(string s) =>
        new(s.Where(char.IsLetterOrDigit).Select(char.ToLowerInvariant).ToArray());

    private StudentImportRow ReadRow(IReadOnlyList<string> cells, Dictionary<string, int> map, int rowNumber)
    {
        string Get(string key) => map.TryGetValue(key, out var i) && i < cells.Count ? cells[i].Trim() : "";
        return new StudentImportRow
        {
            RowNumber = rowNumber,
            FirstName = Get("firstname"),
            LastName = Get("lastname"),
            ClassName = Get("class"),
            SectionName = Get("section"),
            Gender = Get("gender").ToLowerInvariant(),
            Dob = Get("dateofbirth"),
            BloodGroup = Get("bloodgroup"),
            GuardianName = Get("guardianname"),
            GuardianPhone = new string(Get("guardianphone").Where(char.IsDigit).ToArray()),
            Email = Get("email"),
            Address = Get("address"),
            City = Get("city"),
            State = Get("state"),
            Pincode = new string(Get("pincode").Where(char.IsDigit).ToArray()),
            PreviousSchool = Get("previousschool"),
            TcNo = Get("tcno"),
        };
    }

    /// <summary>The first thing wrong with the row, or null when it is fit to admit.</summary>
    private string? Validate(StudentImportRow row, List<(string Name, string Section)> sections)
    {
        if (row.FirstName.Length == 0) return "First Name is required.";
        if (row.LastName.Length == 0) return "Last Name is required.";
        if (row.ClassName.Length == 0) return "Class is required.";
        if (row.SectionName.Length == 0) return "Section is required.";

        var match = sections.FirstOrDefault(s =>
            string.Equals(s.Name, row.ClassName, StringComparison.OrdinalIgnoreCase)
            && string.Equals(s.Section, row.SectionName, StringComparison.OrdinalIgnoreCase));
        if (match.Name is null)
            return sections.Any(s => string.Equals(s.Name, row.ClassName, StringComparison.OrdinalIgnoreCase))
                ? $"{row.ClassName} has no section “{row.SectionName}”."
                : $"There is no class called “{row.ClassName}”.";
        // Written back in the school's own casing, so an imported "GRADE 1" files under "Grade 1"
        // and matches the timetable, marks and fee structure that key off the class name.
        row.ClassName = match.Name;
        row.SectionName = match.Section;

        if (row.Gender.Length == 0) return "Gender is required.";
        if (!Genders.Contains(row.Gender)) return $"Gender must be male, female or other — not “{row.Gender}”.";

        if (row.GuardianName.Length == 0) return "Guardian Name is required.";
        if (row.GuardianPhone.Length == 0) return "Guardian Phone is required.";
        if (row.GuardianPhone.Length != 10) return "Guardian Phone must be 10 digits.";

        if (row.Pincode.Length is not 0 and not 6) return "Pincode must be 6 digits.";
        if (row.Email.Length > 0 && (!row.Email.Contains('@') || row.Email.Contains(' ')))
            return $"“{row.Email}” is not a valid email address.";
        if (row.Dob.Length > 0 && ParseDate(row.Dob) is null)
            return $"“{row.Dob}” is not a date. Use YYYY-MM-DD.";
        if (ParseDate(row.Dob) is { } dob && dob > DateTime.UtcNow.Date)
            return "Date of Birth cannot be in the future.";
        return null;
    }

    /// <summary>
    /// A date from a cell. Excel hands dates over as serial numbers when the column is formatted
    /// as a date and as text when it is not, so both are accepted.
    /// </summary>
    private DateTime? ParseDate(string value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var formats = new[] { "yyyy-MM-dd", "dd-MM-yyyy", "dd/MM/yyyy", "MM/dd/yyyy", "d/M/yyyy", "yyyy/MM/dd" };
        if (DateTime.TryParseExact(value, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, out var exact))
            return exact.Date;
        if (_sheets.DateFromSerial(value) is { } serial) return serial.Date;
        return DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.None, out var loose) ? loose.Date : null;
    }

    private SaveStudentDto ToSaveDto(StudentImportRow row) => new()
    {
        FirstName = row.FirstName,
        LastName = row.LastName,
        ClassName = row.ClassName,
        SectionName = row.SectionName,
        Gender = row.Gender,
        Dob = ParseDate(row.Dob),
        BloodGroup = Blank(row.BloodGroup),
        Email = Blank(row.Email),
        GuardianName = row.GuardianName,
        GuardianPhone = row.GuardianPhone,
        Address = Blank(row.Address),
        City = Blank(row.City),
        State = Blank(row.State),
        Pincode = Blank(row.Pincode),
        PreviousSchool = Blank(row.PreviousSchool),
        TcNo = Blank(row.TcNo),
        // The sheet carries place names, not master ids; the service resolves what it can and
        // keeps the typed text for the rest, exactly as the admission form does.
        StateId = null,
        CityId = null,
    };

    private static string? Blank(string s) => s.Length == 0 ? null : s;
}
