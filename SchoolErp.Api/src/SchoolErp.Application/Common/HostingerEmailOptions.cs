namespace SchoolErp.Application.Common;

/// <summary>
/// The application's outbound mail settings, bound from "HostingerEmailSettings".
///
/// It exists as its own type purely so the endpoints that test the mail path can be handed the
/// settings directly: everything it holds is an <see cref="EmailOptions"/>, and the SMTP sender
/// needs no knowledge of which provider it is talking to.
///
/// Hostinger's own advertised settings, for reference:
///   smtp.hostinger.com, port 465 with SSL on connect, or port 587 with STARTTLS.
///   The username is the complete mailbox address, and the password is that mailbox's own
///   password — not an application-specific one.
/// </summary>
public class HostingerEmailOptions : EmailOptions
{
}
