using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Xml.Linq;

namespace SchoolErp.Infrastructure.Files;

/// <summary>
/// Reads and writes the small slice of .xlsx this application needs, plus .csv.
///
/// An .xlsx file is a zip of XML parts, so nothing beyond <c>System.IO.Compression</c> and
/// <c>System.Xml</c> is required — which is why there is no spreadsheet package referenced.
/// Only the first worksheet is read, only cell values are read (no formulas, no formatting),
/// and the file written uses inline strings so it needs no shared-string table or stylesheet.
/// </summary>
public static class Spreadsheet
{
    private static readonly XNamespace Main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    private static readonly XNamespace Rel = "http://schemas.openxmlformats.org/package/2006/relationships";
    private static readonly XNamespace Doc = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
    private static readonly XNamespace ContentTypes = "http://schemas.openxmlformats.org/package/2006/content-types";

    /// <summary>Whether the name looks like a workbook rather than a delimited text file.</summary>
    public static bool IsWorkbook(string? fileName) =>
        fileName is not null && fileName.EndsWith(".xlsx", StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Every row of the first sheet as a list of cell strings. Rows are padded so a row that
    /// ends early still lines up with the header — .xlsx omits empty trailing cells entirely,
    /// and a naive read would shift every value after a blank into the wrong column.
    /// </summary>
    public static IReadOnlyList<IReadOnlyList<string>> Read(Stream stream, string? fileName)
        => IsWorkbook(fileName) ? ReadXlsx(stream) : ReadCsv(stream);

    /* ============================ reading .xlsx ============================ */

    private static IReadOnlyList<IReadOnlyList<string>> ReadXlsx(Stream stream)
    {
        using var zip = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: true);

        var shared = ReadSharedStrings(zip);
        var sheetPath = FirstSheetPath(zip)
            ?? throw new InvalidDataException("That workbook has no worksheet in it.");
        var entry = zip.GetEntry(sheetPath)
            ?? throw new InvalidDataException("That workbook's first worksheet could not be read.");

        using var sheetStream = entry.Open();
        var sheet = XDocument.Load(sheetStream);

        var rows = new List<IReadOnlyList<string>>();
        var width = 0;
        foreach (var row in sheet.Descendants(Main + "row"))
        {
            var cells = new List<string>();
            foreach (var cell in row.Elements(Main + "c"))
            {
                // Column letters in the cell reference are what place a value: a row with a gap
                // simply omits those <c> elements, so position has to be read, not counted.
                var index = ColumnIndex((string?)cell.Attribute("r"));
                if (index < 0) index = cells.Count;
                while (cells.Count < index) cells.Add("");
                cells.Add(CellValue(cell, shared));
            }
            width = Math.Max(width, cells.Count);
            rows.Add(cells);
        }

        // Pad after the fact: the header may be wider than a short row that follows it.
        foreach (var row in rows)
            while (row.Count < width) ((List<string>)row).Add("");
        return rows;
    }

    private static string? FirstSheetPath(ZipArchive zip)
    {
        // The sheet is found through the workbook's relationships rather than assumed to be
        // sheet1.xml — Excel is free to name and order the parts as it likes.
        var workbook = zip.GetEntry("xl/workbook.xml");
        var rels = zip.GetEntry("xl/_rels/workbook.xml.rels");
        if (workbook is null || rels is null)
            return zip.Entries.FirstOrDefault(e => e.FullName.StartsWith("xl/worksheets/", StringComparison.Ordinal))?.FullName;

        using (var ws = workbook.Open())
        using (var rs = rels.Open())
        {
            var wbDoc = XDocument.Load(ws);
            var relDoc = XDocument.Load(rs);
            var firstSheet = wbDoc.Descendants(Main + "sheet").FirstOrDefault();
            var relId = (string?)firstSheet?.Attribute(Doc + "id");
            var target = relDoc.Descendants(Rel + "Relationship")
                .FirstOrDefault(r => (string?)r.Attribute("Id") == relId)?.Attribute("Target")?.Value;
            if (target is null) return null;
            target = target.TrimStart('/');
            return target.StartsWith("xl/", StringComparison.Ordinal) ? target : "xl/" + target;
        }
    }

    private static string[] ReadSharedStrings(ZipArchive zip)
    {
        var entry = zip.GetEntry("xl/sharedStrings.xml");
        if (entry is null) return Array.Empty<string>();
        using var s = entry.Open();
        var doc = XDocument.Load(s);
        return doc.Descendants(Main + "si")
            // A string split across runs (part of it bold, say) arrives as several <t>.
            .Select(si => string.Concat(si.Descendants(Main + "t").Select(t => t.Value)))
            .ToArray();
    }

    private static string CellValue(XElement cell, string[] shared)
    {
        var type = (string?)cell.Attribute("t");
        if (type == "inlineStr")
            return string.Concat(cell.Descendants(Main + "t").Select(t => t.Value)).Trim();

        var raw = cell.Element(Main + "v")?.Value;
        if (raw is null) return "";

        if (type == "s")
            return int.TryParse(raw, out var i) && i >= 0 && i < shared.Length ? shared[i].Trim() : "";
        if (type == "str" || type == "b")
            return raw.Trim();

        // Dates come through as serial numbers with a date format applied. Formats are not read
        // here, so the value is returned as typed and DateFromSerial handles the conversion
        // wherever a date is expected.
        return raw.Trim();
    }

    /// <summary>
    /// An Excel date serial as a date. Excel counts days from 1899-12-30 (its leap-year bug
    /// makes 1900-01-00 the epoch in practice), so that offset is deliberate, not a typo.
    /// </summary>
    public static DateTime? DateFromSerial(string value)
    {
        if (!double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var serial)) return null;
        if (serial < 1 || serial > 2_958_465) return null;   // 1900-01-01 .. 9999-12-31
        return new DateTime(1899, 12, 30).AddDays(serial);
    }

    private static int ColumnIndex(string? reference)
    {
        if (string.IsNullOrEmpty(reference)) return -1;
        var n = 0;
        foreach (var ch in reference)
        {
            if (ch is >= 'A' and <= 'Z') n = n * 26 + (ch - 'A' + 1);
            else if (ch is >= 'a' and <= 'z') n = n * 26 + (ch - 'a' + 1);
            else break;
        }
        return n - 1;
    }

    /* ============================ reading .csv ============================ */

    private static IReadOnlyList<IReadOnlyList<string>> ReadCsv(Stream stream)
    {
        // Excel writes UTF-8 with a BOM when it saves CSV; detectEncodingFromByteOrderMarks
        // strips it so the first header does not arrive with an invisible character attached.
        using var reader = new StreamReader(stream, Encoding.UTF8, detectEncodingFromByteOrderMarks: true, leaveOpen: true);
        var text = reader.ReadToEnd();

        var rows = new List<IReadOnlyList<string>>();
        var cells = new List<string>();
        var cell = new StringBuilder();
        var quoted = false;

        for (var i = 0; i < text.Length; i++)
        {
            var c = text[i];
            if (quoted)
            {
                if (c == '"')
                {
                    if (i + 1 < text.Length && text[i + 1] == '"') { cell.Append('"'); i++; }
                    else quoted = false;
                }
                else cell.Append(c);
                continue;
            }
            switch (c)
            {
                case '"': quoted = true; break;
                case ',': cells.Add(cell.ToString().Trim()); cell.Clear(); break;
                case '\r': break;    // \r\n is one break, handled by \n
                case '\n':
                    cells.Add(cell.ToString().Trim()); cell.Clear();
                    rows.Add(cells); cells = new List<string>();
                    break;
                default: cell.Append(c); break;
            }
        }
        if (cell.Length > 0 || cells.Count > 0)
        {
            cells.Add(cell.ToString().Trim());
            rows.Add(cells);
        }

        var width = rows.Count == 0 ? 0 : rows.Max(r => r.Count);
        foreach (var row in rows)
            while (row.Count < width) ((List<string>)row).Add("");
        return rows;
    }

    /* ============================ writing .xlsx ============================ */

    /// <summary>
    /// A single-sheet workbook from rows of text. Inline strings throughout, so every value is
    /// written as typed — an admission number like "0042" keeps its leading zero instead of
    /// being read back as the number 42.
    /// </summary>
    public static byte[] Write(string sheetName, IEnumerable<IEnumerable<string>> rows)
    {
        var buffer = new MemoryStream();
        using (var zip = new ZipArchive(buffer, ZipArchiveMode.Create, leaveOpen: true))
        {
            AddEntry(zip, "[Content_Types].xml", new XDocument(
                new XElement(ContentTypes + "Types",
                    new XElement(ContentTypes + "Default", new XAttribute("Extension", "rels"),
                        new XAttribute("ContentType", "application/vnd.openxmlformats-package.relationships+xml")),
                    new XElement(ContentTypes + "Default", new XAttribute("Extension", "xml"),
                        new XAttribute("ContentType", "application/xml")),
                    new XElement(ContentTypes + "Override", new XAttribute("PartName", "/xl/workbook.xml"),
                        new XAttribute("ContentType", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml")),
                    new XElement(ContentTypes + "Override", new XAttribute("PartName", "/xl/worksheets/sheet1.xml"),
                        new XAttribute("ContentType", "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml")))));

            AddEntry(zip, "_rels/.rels", new XDocument(
                new XElement(Rel + "Relationships",
                    new XElement(Rel + "Relationship",
                        new XAttribute("Id", "rId1"),
                        new XAttribute("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"),
                        new XAttribute("Target", "xl/workbook.xml")))));

            AddEntry(zip, "xl/workbook.xml", new XDocument(
                new XElement(Main + "workbook", new XAttribute(XNamespace.Xmlns + "r", Doc),
                    new XElement(Main + "sheets",
                        new XElement(Main + "sheet",
                            new XAttribute("name", Clean(sheetName)),
                            new XAttribute("sheetId", "1"),
                            new XAttribute(Doc + "id", "rId1"))))));

            AddEntry(zip, "xl/_rels/workbook.xml.rels", new XDocument(
                new XElement(Rel + "Relationships",
                    new XElement(Rel + "Relationship",
                        new XAttribute("Id", "rId1"),
                        new XAttribute("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"),
                        new XAttribute("Target", "worksheets/sheet1.xml")))));

            var sheetData = new XElement(Main + "sheetData");
            var rowNo = 1;
            foreach (var row in rows)
            {
                var rowEl = new XElement(Main + "row", new XAttribute("r", rowNo));
                var col = 0;
                foreach (var value in row)
                {
                    rowEl.Add(new XElement(Main + "c",
                        new XAttribute("r", $"{ColumnName(col)}{rowNo}"),
                        new XAttribute("t", "inlineStr"),
                        new XElement(Main + "is", new XElement(Main + "t", value ?? ""))));
                    col++;
                }
                sheetData.Add(rowEl);
                rowNo++;
            }
            AddEntry(zip, "xl/worksheets/sheet1.xml", new XDocument(
                new XElement(Main + "worksheet", sheetData)));
        }
        return buffer.ToArray();
    }

    private static void AddEntry(ZipArchive zip, string path, XDocument doc)
    {
        using var s = zip.CreateEntry(path, CompressionLevel.Optimal).Open();
        doc.Save(s);
    }

    private static string ColumnName(int index)
    {
        var name = "";
        for (var n = index; n >= 0; n = n / 26 - 1) name = (char)('A' + n % 26) + name;
        return name;
    }

    /// <summary>Excel refuses a sheet name over 31 characters or containing []:*?/\.</summary>
    private static string Clean(string name)
    {
        var safe = new string(name.Where(c => !"[]:*?/\\".Contains(c)).ToArray());
        if (safe.Length == 0) safe = "Sheet1";
        return safe.Length > 31 ? safe[..31] : safe;
    }
}
