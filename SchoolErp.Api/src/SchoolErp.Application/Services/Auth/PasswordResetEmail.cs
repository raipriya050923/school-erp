using System.Net;
using System.Text;

namespace SchoolErp.Application.Services.Auth;

/// <summary>
/// The message sent when someone asks to reset a forgotten password: a link that carries the
/// one-time token, how long it lasts, and what to do if they never asked for it.
///
/// Composed here rather than inside <see cref="AuthService"/> for the same reason as
/// <see cref="WelcomeEmail"/>: the wording can be read and changed without going near the
/// authentication path, and one source backs both the HTML and plain-text parts.
///
/// The link is the whole message. A raw token is something a reader has to copy out of a mail
/// client and paste into a form, which is exactly where people give up — and worse, it trains
/// them to paste secrets into pages they arrived at themselves.
/// </summary>
public static class PasswordResetEmail
{
    public static string Subject(string schoolName) =>
        string.IsNullOrWhiteSpace(schoolName)
            ? "Reset your password"
            : $"Reset your {schoolName} password";

    /// <summary>
    /// How long the link is good for, written the way a person would say it. Derived from the
    /// real lifetime rather than hardcoded, so the text cannot drift from what the token does.
    /// </summary>
    public static string Validity(TimeSpan lifetime) => lifetime.TotalHours switch
    {
        >= 2 => $"{(int)lifetime.TotalHours} hours",
        >= 1 => "1 hour",
        _ => $"{(int)lifetime.TotalMinutes} minutes",
    };

    /// <summary>
    /// The plain-text part. The URL is printed in full: there is no such thing as a button here,
    /// and a reader on a stripped-down client still needs something they can act on.
    /// </summary>
    public static string PlainBody(string fullName, string schoolName, string resetLink,
        TimeSpan lifetime)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"Dear {fullName},");
        sb.AppendLine();
        sb.AppendLine(string.IsNullOrWhiteSpace(schoolName)
            ? "We received a request to reset the password for your account."
            : $"We received a request to reset the password for your {schoolName} account.");
        sb.AppendLine();
        sb.AppendLine("Open this link to choose a new one:");
        sb.AppendLine();
        sb.AppendLine($"    {resetLink}");
        sb.AppendLine();
        sb.AppendLine($"The link is valid for {Validity(lifetime)} and can be used once.");
        sb.AppendLine();
        sb.AppendLine("IF YOU DID NOT ASK FOR THIS, you can ignore this email. Your password has");
        sb.AppendLine("not changed, and it will not change unless someone opens the link above.");
        sb.AppendLine();
        sb.AppendLine("Please do not reply to this message — it is sent from an unattended mailbox.");
        return sb.ToString();
    }

    /// <summary>
    /// The HTML part. Tables and inline styles, matching <see cref="WelcomeEmail"/>: mail clients
    /// are a decade behind browsers and a modern layout collapses in Outlook.
    /// </summary>
    public static string HtmlBody(string fullName, string schoolName, string resetLink,
        TimeSpan lifetime)
    {
        string E(string? v) => WebUtility.HtmlEncode(v ?? string.Empty);

        var heading = string.IsNullOrWhiteSpace(schoolName) ? "Reset your password" : E(schoolName);
        var intro = string.IsNullOrWhiteSpace(schoolName)
            ? "We received a request to reset the password for your account."
            : $"We received a request to reset the password for your {E(schoolName)} account.";
        var link = E(resetLink);

        return $@"<!doctype html>
<html><body style=""margin:0;padding:0;background:#f4f6fa;"">
  <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" style=""background:#f4f6fa;padding:24px 12px;"">
    <tr><td align=""center"">
      <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0""
             style=""max-width:520px;background:#ffffff;border:1px solid #e3e8ef;border-radius:14px;
                    font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#1f2733;"">
        <tr><td style=""padding:26px 28px 0;"">
          <div style=""font-size:19px;font-weight:700;letter-spacing:-0.01em;"">{heading}</div>
          <div style=""font-size:12px;color:#6b7684;margin-top:3px;"">Password reset</div>
        </td></tr>

        <tr><td style=""padding:18px 28px 0;font-size:14px;line-height:1.6;"">
          <p style=""margin:0 0 10px;"">Dear {E(fullName)},</p>
          <p style=""margin:0 0 16px;"">{intro}</p>
        </td></tr>

        <tr><td style=""padding:0 28px 20px;"">
          <a href=""{link}""
             style=""display:inline-block;background:#2563eb;color:#ffffff;text-decoration:none;
                    font-weight:600;font-size:14px;padding:11px 22px;border-radius:8px;"">
            Choose a new password
          </a>
        </td></tr>

        <!-- The same URL as text. Plenty of clients refuse to render the button, and a reader
             who cannot click it still has to be able to get there. -->
        <tr><td style=""padding:0 28px 18px;font-size:12px;line-height:1.6;color:#6b7684;"">
          If the button does not work, copy this address into your browser:<br />
          <a href=""{link}"" style=""color:#2563eb;word-break:break-all;"">{link}</a>
        </td></tr>

        <tr><td style=""padding:0 28px 4px;"">
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0""
                 style=""background:#fff8e6;border:1px solid #f5dfa6;border-radius:10px;"">
            <tr><td style=""padding:13px 16px;font-size:13px;line-height:1.6;color:#7a5b00;"">
              <b>The link is valid for {E(Validity(lifetime))} and can be used once.</b><br />
              If you did not ask for this, you can ignore this email. Your password has not
              changed, and it will not change unless someone opens the link above.
            </td></tr>
          </table>
        </td></tr>

        <tr><td style=""padding:18px 28px 26px;font-size:11.5px;color:#8a94a2;line-height:1.6;border-top:1px solid #eef1f6;"">
          Please do not reply to this message — it is sent from an unattended mailbox.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>";
    }
}
