using System.Text.Json;
using System.Text.Json.Serialization;
using SchoolErp.Application.Common;

namespace SchoolErp.Api.Middleware;

/// <summary>Translates Application exceptions into clean JSON HTTP responses.</summary>
public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    /// <summary>
    /// What a user is shown when something broke that is not their doing. Deliberately says
    /// nothing about the cause — the cause rides along in <c>detail</c> for whoever is looking
    /// at the network tab, and in the log under the same trace id.
    /// </summary>
    private const string GenericMessage = "An error occurred. Please contact administrator.";

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (NotFoundException ex)
        {
            await WriteAsync(context, StatusCodes.Status404NotFound, "not_found", ex.Message);
        }
        catch (ValidationException ex)
        {
            await WriteAsync(context, StatusCodes.Status400BadRequest, "validation_error", ex.Message);
        }
        catch (ForbiddenException ex)
        {
            await WriteAsync(context, StatusCodes.Status403Forbidden, "forbidden", ex.Message);
        }
        catch (Exception ex)
        {
            // The trace id is on both the response and the log line, so a screenshot of the
            // former is enough to find the latter — the response carries no stack trace.
            var traceId = context.TraceIdentifier;
            _logger.LogError(ex, "Unhandled exception (traceId {TraceId})", traceId);
            await WriteAsync(context, StatusCodes.Status500InternalServerError, "server_error",
                GenericMessage, Describe(ex), traceId);
        }
    }

    /// <summary>
    /// The exception and everything it wraps, innermost cause included. A schema drift surfaces
    /// as a MySqlException several levels down, and only its message names the column — so the
    /// chain is walked rather than reporting the outermost type alone.
    /// </summary>
    private static string Describe(Exception ex)
    {
        var parts = new List<string>();
        for (Exception? e = ex; e is not null; e = e.InnerException)
            parts.Add($"{e.GetType().Name}: {e.Message}");
        return string.Join(" -> ", parts);
    }

    private static async Task WriteAsync(HttpContext context, int status, string code, string message,
        string? detail = null, string? traceId = null)
    {
        context.Response.StatusCode = status;
        context.Response.ContentType = "application/json";
        var payload = JsonSerializer.Serialize(new { error = code, message, detail, traceId },
            new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                // The handled cases carry a message that already explains itself; only the
                // unexpected ones add detail, and nulls would just be noise on the rest.
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            });
        await context.Response.WriteAsync(payload);
    }
}
