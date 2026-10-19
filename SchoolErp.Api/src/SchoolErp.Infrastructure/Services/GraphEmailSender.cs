using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using SchoolErp.Application.Common;
using SchoolErp.Application.Interfaces.Services;

namespace SchoolErp.Infrastructure.Services;

/// <summary>
/// Sends through Microsoft Graph with OAuth 2.0 client credentials.
///
/// Two calls: one to Entra for a token, one to Graph to send. The token is cached until
/// shortly before it expires, because they last about an hour and fetching one per message
/// would both be slow and look like a brute-force attempt from Entra's side.
///
/// Nothing here logs the client secret or the access token, which the handover calls out
/// explicitly. The failure paths log the status and Graph's own message instead — those carry
/// the reason without carrying the credential.
/// </summary>
public class GraphEmailSender : INotificationSender
{
    private const string Scope = "https://graph.microsoft.com/.default";

    private readonly IHttpClientFactory _http;
    private readonly IEmailSettingsProvider _settings;
    private readonly ILogger<GraphEmailSender> _logger;

    // Shared across requests, so one token serves every message until it ages out.
    private static readonly SemaphoreSlim TokenGate = new(1, 1);
    private static string? _token;
    private static DateTime _tokenExpiresUtc = DateTime.MinValue;

    public GraphEmailSender(
        IHttpClientFactory http,
        IEmailSettingsProvider settings,
        ILogger<GraphEmailSender> logger)
    {
        _http = http;
        _settings = settings;
        _logger = logger;
    }

    public Task SendEmailAsync(string toEmail, string subject, string body,
        CancellationToken ct = default)
        => SendAsync(toEmail, subject, body, isHtml: false, ct);

    /// <summary>
    /// Graph takes one body with one content type, so unlike SMTP there is no
    /// multipart/alternative to build: the HTML rendering is sent and Outlook derives its own
    /// plain-text fallback.
    /// </summary>
    public Task SendEmailAsync(string toEmail, string subject, string htmlBody, string plainBody,
        CancellationToken ct = default)
        => SendAsync(toEmail, subject, htmlBody, isHtml: true, ct);

    public async Task SendAsync(string toEmail, string subject, string body, bool isHtml,
        CancellationToken ct = default)
    {
        var settings = (await _settings.GetMailSettingsAsync(ct)).Graph;
        if (!settings.IsConfigured)
            throw new InvalidOperationException(
                "Microsoft Graph is selected but not configured. Set the tenant, client id, " +
                "secret and sender mailbox.");

        var token = await GetTokenAsync(settings, ct);

        var payload = new
        {
            message = new
            {
                subject,
                body = new { contentType = isHtml ? "HTML" : "Text", content = body },
                toRecipients = new[]
                {
                    new { emailAddress = new { address = toEmail } },
                },
            },
            // Kept, so there is a record on the mailbox of what the application sent. Support
            // questions about a message nobody can find are otherwise unanswerable.
            saveToSentItems = true,
        };

        var client = _http.CreateClient(nameof(GraphEmailSender));
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://graph.microsoft.com/v1.0/users/{settings.FromAddress}/sendMail");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        request.Content = new StringContent(
            JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

        using var response = await client.SendAsync(request, ct);

        // Graph answers 202 and nothing else on success — it has accepted the send, not
        // completed it.
        if (response.StatusCode == HttpStatusCode.Accepted) return;

        var detail = await response.Content.ReadAsStringAsync(ct);

        // A 401 here with a token that was fine a moment ago means the cached one aged out
        // against a clock we cannot see. Drop it so the next attempt fetches a fresh one
        // rather than failing identically for the next hour.
        if (response.StatusCode == HttpStatusCode.Unauthorized) Invalidate();

        _logger.LogError("Graph sendMail failed: {Status} {Detail}", (int)response.StatusCode, detail);
        throw new InvalidOperationException(
            $"Microsoft Graph refused the message ({(int)response.StatusCode}). {Summarise(detail)}");
    }

    /// <summary>Drops the cached token; the next send fetches a new one.</summary>
    public static void Invalidate()
    {
        _token = null;
        _tokenExpiresUtc = DateTime.MinValue;
    }

    private async Task<string> GetTokenAsync(GraphMailOptions o, CancellationToken ct)
    {
        if (_token is not null && DateTime.UtcNow < _tokenExpiresUtc) return _token;

        await TokenGate.WaitAsync(ct);
        try
        {
            if (_token is not null && DateTime.UtcNow < _tokenExpiresUtc) return _token;

            var client = _http.CreateClient(nameof(GraphEmailSender));
            using var content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["client_id"] = o.ClientId,
                ["client_secret"] = o.ClientSecret,
                ["scope"] = Scope,
                ["grant_type"] = "client_credentials",
            });

            using var response = await client.PostAsync(
                $"https://login.microsoftonline.com/{o.TenantId}/oauth2/v2.0/token", content, ct);
            var text = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                // The body carries the AADSTS code, which is the whole diagnosis — 7000215 is
                // a wrong secret, 700016 an unknown application. It contains no credential.
                _logger.LogError("Entra token request failed: {Status} {Detail}",
                    (int)response.StatusCode, text);
                throw new InvalidOperationException(
                    $"Microsoft would not issue a token. {Summarise(text)}");
            }

            using var json = JsonDocument.Parse(text);
            var token = json.RootElement.TryGetProperty("access_token", out var t)
                ? t.GetString()
                : null;
            if (string.IsNullOrWhiteSpace(token))
                throw new InvalidOperationException("Microsoft returned no access token.");

            var seconds = json.RootElement.TryGetProperty("expires_in", out var e)
                ? e.GetInt32()
                : 3600;
            // Retired a minute early, so a message is never sent with a token that expires
            // mid-flight.
            _tokenExpiresUtc = DateTime.UtcNow.AddSeconds(Math.Max(60, seconds - 60));
            _token = token;
            return token;
        }
        finally
        {
            TokenGate.Release();
        }
    }

    /// <summary>
    /// Pulls the readable part out of an Entra or Graph error body. Those carry an AADSTS code
    /// and a paragraph of guidance; the paragraph is what someone needs and the raw JSON is
    /// not.
    /// </summary>
    private static string Summarise(string body)
    {
        if (string.IsNullOrWhiteSpace(body)) return string.Empty;
        try
        {
            using var json = JsonDocument.Parse(body);
            var root = json.RootElement;

            if (root.TryGetProperty("error_description", out var d))
                return d.GetString()?.Split('\n')[0] ?? string.Empty;

            if (root.TryGetProperty("error", out var err) &&
                err.ValueKind == JsonValueKind.Object &&
                err.TryGetProperty("message", out var m))
                return m.GetString() ?? string.Empty;

            if (root.TryGetProperty("error", out var simple) &&
                simple.ValueKind == JsonValueKind.String)
                return simple.GetString() ?? string.Empty;
        }
        catch (JsonException)
        {
            // Not JSON — an HTML error page from a proxy, most likely.
        }
        return body.Length > 200 ? body[..200] : body;
    }
}
