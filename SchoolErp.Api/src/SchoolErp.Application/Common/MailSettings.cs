namespace SchoolErp.Application.Common;

/// <summary>
/// Microsoft Graph, sending as a named mailbox with OAuth 2.0 client credentials.
///
/// Not SMTP with different values: there is no mailbox password. The application proves it is
/// itself against Entra, receives a token, and posts the message to Graph. Authorisation to
/// send as the mailbox comes from Exchange Application RBAC, granted outside this codebase.
/// </summary>
public class GraphMailOptions
{
    public string TenantId { get; set; } = string.Empty;
    public string ClientId { get; set; } = string.Empty;

    /// <summary>
    /// The secret VALUE, not the secret ID — the most common cause of AADSTS7000215. Never
    /// logged, never returned by the API, and stored encrypted.
    /// </summary>
    public string ClientSecret { get; set; } = string.Empty;

    /// <summary>
    /// The mailbox to send as. Part of the Graph URL rather than only a From header, so it has
    /// to be a real mailbox the application has RBAC over.
    /// </summary>
    public string FromAddress { get; set; } = string.Empty;
    public string FromName { get; set; } = string.Empty;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(TenantId) &&
        !string.IsNullOrWhiteSpace(ClientId) &&
        !string.IsNullOrWhiteSpace(ClientSecret) &&
        !string.IsNullOrWhiteSpace(FromAddress);
}

/// <summary>
/// Both ways of sending, and which one is live.
///
/// The inactive provider keeps its settings. Switching to find out whether a delivery problem
/// follows the message or the route should be one change, not a re-entry of four fields while
/// something is broken.
/// </summary>
public class MailSettings
{
    /// <summary>smtp | graph</summary>
    public string Provider { get; set; } = "smtp";

    public EmailOptions Smtp { get; set; } = new();
    public GraphMailOptions Graph { get; set; } = new();

    public bool UsesGraph => string.Equals(Provider, "graph", StringComparison.OrdinalIgnoreCase);
}
