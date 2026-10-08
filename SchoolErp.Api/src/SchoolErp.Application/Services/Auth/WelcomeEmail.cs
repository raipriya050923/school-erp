using System.Net;
using System.Text;

namespace SchoolErp.Application.Services.Auth;

/// <summary>
/// The message a newly registered person receives: a welcome from their school, what their
/// username is, the password they were issued, what the portal is for, and that they will be
/// asked to replace the password on first sign-in.
///
/// Composed here rather than inside the provisioner so the wording can be read, reviewed and
/// changed without going near account creation, and so the same text backs both the HTML and
/// plain-text parts. Every value that comes from the database is HTML-encoded on the way in:
/// a pupil called "Tom &amp; Jerry" must not be able to break the markup, let alone inject it.
/// </summary>
public static class WelcomeEmail
{
    /// <summary>Turns the stored user_type into something a parent would recognise.</summary>
    public static string RoleLabel(string userType) => userType switch
    {
        "school_admin" => "school administrator",
        "super_admin" => "platform administrator",
        "teacher" => "teacher",
        "staff" => "staff",
        "student" => "student",
        "parent" => "parent",
        _ => "portal",
    };

    /// <summary>
    /// What this person will actually use the portal for. A welcome that only hands over a
    /// password tells someone nothing about why they should sign in at all, and these lines cost
    /// nothing to carry.
    /// </summary>
    private static string[] WhatYouCanDo(string userType) => userType switch
    {
        "student" => new[]
        {
            "See your class timetable and daily attendance",
            "Check exam schedules, marks and published results",
            "View fee invoices and submit payment details",
            "Read notices from the school",
        },
        "parent" => new[]
        {
            "Follow your child's attendance day by day",
            "See exam results as soon as the school publishes them",
            "View fee invoices and submit payment details",
            "Read notices from the school",
        },
        "teacher" or "staff" => new[]
        {
            "Mark daily attendance for your class",
            "Enter exam marks for the subjects you teach",
            "See your timetable and the students in each section",
            "Apply for leave and read school notices",
        },
        "school_admin" => new[]
        {
            "Admit students and register staff",
            "Set fee structures and raise invoices",
            "Schedule exams and publish results",
            "Manage classes, subjects, timetables and notices",
        },
        _ => Array.Empty<string>(),
    };

    public static string Subject(string schoolName) =>
        string.IsNullOrWhiteSpace(schoolName)
            ? "Welcome — your login details"
            : $"Welcome to {schoolName} — your login details";

    /// <summary>
    /// The plain-text part. Sent as the body when HTML is not wanted, and worth keeping readable
    /// on its own: a good many school inboxes are read on phones that strip styling anyway.
    /// </summary>
    public static string PlainBody(string fullName, string schoolName, string roleLabel,
        string username, string password, string? portalUrl, string userType = "")
    {
        var school = string.IsNullOrWhiteSpace(schoolName) ? "your school" : schoolName;
        var sb = new StringBuilder();

        sb.AppendLine($"Welcome to {school}, {fullName}!");
        sb.AppendLine();
        sb.AppendLine($"A {roleLabel} account has been created for you, and the portal is ready");
        sb.AppendLine("whenever you are.");
        sb.AppendLine();
        sb.AppendLine("YOUR SIGN-IN DETAILS");
        sb.AppendLine($"    Username : {username}");
        sb.AppendLine($"    Password : {password}");
        if (!string.IsNullOrWhiteSpace(portalUrl))
        {
            sb.AppendLine();
            sb.AppendLine($"    Sign in at: {portalUrl}");
        }

        var things = WhatYouCanDo(userType);
        if (things.Length > 0)
        {
            sb.AppendLine();
            sb.AppendLine("WHAT YOU CAN DO");
            foreach (var t in things) sb.AppendLine($"  - {t}");
        }

        sb.AppendLine();
        sb.AppendLine("PLEASE CHANGE YOUR PASSWORD");
        sb.AppendLine("The password above was issued by the school and has been seen by the office,");
        sb.AppendLine("so it is not private to you yet. You will be asked to choose your own the");
        sb.AppendLine("first time you sign in, and the portal stays closed until you do.");
        sb.AppendLine();
        sb.AppendLine($"We are glad to have you with us.");
        sb.AppendLine($"— {school}");
        sb.AppendLine();
        sb.AppendLine("Please do not reply to this message; it is sent from an unattended mailbox.");
        sb.AppendLine("If you were not expecting this email, contact the school office.");
        return sb.ToString();
    }

    /// <summary>
    /// The HTML part. Laid out with tables and inline styles on purpose: mail clients are a
    /// decade behind browsers, and a flex layout that looks right in a browser collapses in
    /// Outlook. Every coloured panel also carries a bgcolor, so a client that drops the CSS
    /// still shows the structure rather than a wall of white.
    /// </summary>
    public static string HtmlBody(string fullName, string schoolName, string roleLabel,
        string username, string password, string? portalUrl, string userType = "")
    {
        string E(string? v) => WebUtility.HtmlEncode(v ?? string.Empty);

        var school = string.IsNullOrWhiteSpace(schoolName) ? "your school" : schoolName;
        var initial = E(school.Trim().Substring(0, 1).ToUpperInvariant());

        var button = string.IsNullOrWhiteSpace(portalUrl)
            ? ""
            : $@"<table role=""presentation"" cellpadding=""0"" cellspacing=""0"" style=""margin:0 0 4px;"">
                   <tr><td bgcolor=""#2563eb"" style=""border-radius:9px;"">
                     <a href=""{E(portalUrl)}""
                        style=""display:inline-block;color:#ffffff;text-decoration:none;font-weight:600;
                               font-size:14.5px;padding:12px 26px;border-radius:9px;"">Sign in to the portal &rarr;</a>
                   </td></tr>
                 </table>";

        var things = WhatYouCanDo(userType);
        var list = things.Length == 0 ? "" : $@"
        <tr><td style=""padding:26px 30px 0;"">
          <div style=""font-size:11.5px;font-weight:700;letter-spacing:0.07em;text-transform:uppercase;color:#8a94a2;padding-bottom:10px;"">
            What you can do
          </div>
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" style=""font-size:14px;color:#3c4654;"">
            {string.Concat(things.Select(t => $@"
            <tr>
              <td width=""22"" valign=""top"" style=""padding:4px 0;color:#2563eb;font-weight:700;"">&#10003;</td>
              <td style=""padding:4px 0;line-height:1.55;"">{E(t)}</td>
            </tr>"))}
          </table>
        </td></tr>";

        return $@"<!doctype html>
<html><body style=""margin:0;padding:0;background:#eef1f6;"">
  <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" bgcolor=""#eef1f6"" style=""padding:28px 12px;"">
    <tr><td align=""center"">
      <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0""
             style=""max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden;
                    box-shadow:0 1px 3px rgba(16,24,40,0.08);
                    font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1f2733;"">

        <!-- Brand band. A solid bgcolor sits under the gradient for clients that drop it. -->
        <tr><td bgcolor=""#2563eb""
                style=""background:linear-gradient(135deg,#2563eb 0%,#1d4ed8 60%,#1e40af 100%);padding:28px 30px;"">
          <table role=""presentation"" cellpadding=""0"" cellspacing=""0"">
            <tr>
              <td width=""46"" valign=""middle"">
                <div style=""width:44px;height:44px;border-radius:12px;background:rgba(255,255,255,0.18);
                            color:#ffffff;font-size:20px;font-weight:700;text-align:center;line-height:44px;"">{initial}</div>
              </td>
              <td width=""14""></td>
              <td valign=""middle"">
                <div style=""color:#ffffff;font-size:19px;font-weight:700;letter-spacing:-0.01em;"">{E(school)}</div>
                <div style=""color:#c7d7fb;font-size:12.5px;margin-top:2px;"">Pathshala School ERP</div>
              </td>
            </tr>
          </table>
        </td></tr>

        <tr><td style=""padding:30px 30px 0;"">
          <div style=""font-size:22px;font-weight:800;letter-spacing:-0.02em;line-height:1.3;"">
            Welcome to {E(school)}, {E(fullName)}! 🎉
          </div>
          <p style=""margin:12px 0 0;font-size:14.5px;line-height:1.65;color:#3c4654;"">
            A <b>{E(roleLabel)}</b> account has been created for you, and the portal is ready
            whenever you are. Here is everything you need to sign in.
          </p>
        </td></tr>

        <tr><td style=""padding:22px 30px 0;"">
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" bgcolor=""#f7f9fc""
                 style=""background:#f7f9fc;border:1px solid #e3e8ef;border-radius:12px;"">
            <tr><td style=""padding:16px 18px 6px;font-size:11.5px;font-weight:700;letter-spacing:0.07em;
                            text-transform:uppercase;color:#8a94a2;"">Your sign-in details</td></tr>
            <tr>
              <td style=""padding:0 18px 6px;"">
                <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"">
                  <tr>
                    <td width=""86"" style=""font-size:12.5px;color:#6b7684;padding:6px 0;"">Username</td>
                    <td style=""font-size:15.5px;font-weight:700;padding:6px 0;
                               font-family:Consolas,Menlo,'Courier New',monospace;"">{E(username)}</td>
                  </tr>
                  <tr>
                    <td style=""font-size:12.5px;color:#6b7684;padding:6px 0 16px;"">Password</td>
                    <td style=""font-size:15.5px;font-weight:700;padding:6px 0 16px;
                               font-family:Consolas,Menlo,'Courier New',monospace;"">{E(password)}</td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </td></tr>

        <tr><td style=""padding:22px 30px 0;"">{button}</td></tr>
        {list}

        <tr><td style=""padding:26px 30px 0;"">
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" bgcolor=""#fff8e6""
                 style=""background:#fff8e6;border:1px solid #f5dfa6;border-radius:12px;"">
            <tr>
              <td width=""26"" valign=""top"" style=""padding:14px 0 14px 16px;font-size:15px;"">&#128274;</td>
              <td style=""padding:14px 16px 14px 8px;font-size:13px;line-height:1.6;color:#7a5b00;"">
                <b>Please change your password after signing in.</b><br />
                It was issued by the school and has been seen by the office, so it is not private
                to you yet. You will be asked to choose your own the first time you sign in, and
                the portal stays closed until you do.
              </td>
            </tr>
          </table>
        </td></tr>

        <tr><td style=""padding:24px 30px 0;font-size:14.5px;line-height:1.6;color:#3c4654;"">
          We are glad to have you with us.<br />
          <span style=""color:#6b7684;"">&mdash; {E(school)}</span>
        </td></tr>

        <tr><td style=""padding:22px 30px 28px;"">
          <div style=""border-top:1px solid #eef1f6;padding-top:16px;font-size:11.5px;line-height:1.6;color:#8a94a2;"">
            Please do not reply to this message; it is sent from an unattended mailbox.
            If you were not expecting this email, contact the school office.
          </div>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>";
    }
}
