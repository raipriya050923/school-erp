using System.Security.Cryptography;

namespace SchoolErp.Application.Common;

/// <summary>
/// Builds the username + first-login password handed to a newly created account (school admin,
/// teacher or student). Passwords are read off a screen and retyped, so the alphabets
/// deliberately exclude characters that are easy to confuse (0/O, 1/l/I).
/// </summary>
public static class CredentialGenerator
{
    private const string Lower = "abcdefghijkmnpqrstuvwxyz";   // no l, o
    private const string Upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";   // no I, O
    private const string Digits = "23456789";                  // no 0, 1
    private const string Symbols = "@#$%&*!?";

    /// <summary>
    /// Turns a school name into a login stem, e.g. "Sunrise Public School" -> "sunrise.admin".
    /// </summary>
    public static string UsernameStem(string schoolName)
    {
        var word = new string(schoolName.Trim().ToLowerInvariant()
            .TakeWhile(c => !char.IsWhiteSpace(c))
            .Where(char.IsLetterOrDigit)
            .ToArray());
        if (word.Length < 3) word = new string(schoolName.ToLowerInvariant().Where(char.IsLetterOrDigit).Take(8).ToArray());
        if (word.Length == 0) word = "school";
        return $"{word}.admin";
    }

    /// <summary>
    /// Turns a person's name into a login stem, e.g. ("Rajesh", "Koirala") -> "rajesh.koirala".
    /// Falls back to whichever part is present so a one-name record still gets a usable stem.
    /// </summary>
    public static string UsernameStem(string firstName, string lastName)
    {
        var first = Slug(firstName);
        var last = Slug(lastName);
        if (first.Length == 0 && last.Length == 0) return "user";
        if (first.Length == 0) return last;
        if (last.Length == 0) return first;
        return $"{first}.{last}";
    }

    private static string Slug(string? s) =>
        new string((s ?? "").ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());

    /// <summary>
    /// A 12-character password guaranteed to contain each character class. Generated with a
    /// CSPRNG — never a <see cref="Random"/>, since this is a real credential.
    /// </summary>
    public static string Password()
    {
        const string all = Lower + Upper + Digits + Symbols;
        var chars = new List<char>(12)
        {
            Pick(Upper), Pick(Lower), Pick(Digits), Pick(Symbols),
        };
        while (chars.Count < 12) chars.Add(Pick(all));

        // Fisher-Yates so the guaranteed classes aren't always in the same positions.
        for (var i = chars.Count - 1; i > 0; i--)
        {
            var j = RandomNumberGenerator.GetInt32(i + 1);
            (chars[i], chars[j]) = (chars[j], chars[i]);
        }
        return new string(chars.ToArray());
    }

    private static char Pick(string set) => set[RandomNumberGenerator.GetInt32(set.Length)];
}
