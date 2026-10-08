using System.Globalization;
using System.Text;

namespace SchoolErp.Application.Common;

/// <summary>
/// Writes a rupee amount out in words, the way a receipt has to carry it.
///
/// Words beside figures is not decoration: it is what stops a 1 becoming a 7 on a printed slip
/// after it has left the office. Grouped the Indian way — thousand, lakh, crore — because that
/// is what the reader expects; the Western short scale would read as a mistake on a receipt in
/// Kathmandu or Delhi.
/// </summary>
public static class AmountInWords
{
    private static readonly string[] Ones =
    {
        "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
        "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen",
        "Eighteen", "Nineteen",
    };

    private static readonly string[] Tens =
    {
        "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety",
    };

    /// <summary>e.g. 1560.50 → "Rupees One Thousand Five Hundred Sixty and Fifty Paisa only".</summary>
    public static string Rupees(decimal amount)
    {
        if (amount < 0) return "Minus " + Rupees(-amount);

        var rounded = decimal.Round(amount, 2, MidpointRounding.AwayFromZero);
        var whole = (long)decimal.Truncate(rounded);
        // Multiplied before converting so 0.07 does not arrive as 6 through binary rounding.
        var paisa = (int)decimal.Round((rounded - whole) * 100, 0, MidpointRounding.AwayFromZero);

        var sb = new StringBuilder("Rupees ");
        sb.Append(whole == 0 ? "Zero" : Indian(whole));
        if (paisa > 0) sb.Append(" and ").Append(Below100(paisa)).Append(" Paisa");
        sb.Append(" only");
        return sb.ToString();
    }

    /// <summary>
    /// Crore, lakh, thousand, hundred — then the last two digits. The groups below a hundred are
    /// the only place the teens need their own words, which is why they sit in one table.
    /// </summary>
    private static string Indian(long n)
    {
        var parts = new List<string>();

        void Take(long unit, string name)
        {
            var count = n / unit;
            if (count <= 0) return;
            parts.Add($"{Indian(count)} {name}");
            n %= unit;
        }

        Take(10_000_000, "Crore");
        Take(100_000, "Lakh");
        Take(1_000, "Thousand");
        Take(100, "Hundred");

        if (n > 0) parts.Add(Below100((int)n));
        return string.Join(" ", parts);
    }

    private static string Below100(int n)
    {
        if (n < 20) return Ones[n];
        var tens = Tens[n / 10];
        var ones = n % 10;
        return ones == 0 ? tens : $"{tens} {Ones[ones]}";
    }

    /// <summary>The figure as it is printed beside the words, grouped Indian-style.</summary>
    public static string Figures(decimal amount) =>
        amount.ToString("#,##,##0.00", CultureInfo.GetCultureInfo("en-IN"));
}
