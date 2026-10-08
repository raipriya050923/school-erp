using Microsoft.OpenApi.Any;
using Microsoft.OpenApi.Models;
using SchoolErp.Api.Controllers;
using SchoolErp.Application.Common;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace SchoolErp.Api.Swagger;

/// <summary>
/// Shows the configured test recipient in Swagger's example body for the mail test.
///
/// Without it the example reads <c>"to": "string"</c>, and pressing Try it out sends that
/// verbatim — a diagnostic endpoint whose one-click path fails for a reason that has nothing to
/// do with the mail server is worse than no example at all. The address comes from
/// EmailSettings:TestRecipient rather than being written here, so there is still one place to
/// change it.
/// </summary>
public class TestEmailExampleFilter : ISchemaFilter
{
    private readonly HostingerEmailOptions _options;
    public TestEmailExampleFilter(HostingerEmailOptions options) => _options = options;

    public void Apply(OpenApiSchema schema, SchemaFilterContext context)
    {
        if (context.Type != typeof(SendHostingerEmailDto)) return;
        var options = _options;

        var to = string.IsNullOrWhiteSpace(options.TestRecipient)
            ? "someone@example.com"
            : options.TestRecipient.Trim();

        var example = new OpenApiObject
        {
            ["to"] = new OpenApiString(to),
            ["subject"] = new OpenApiString($"Test email from {options.SenderName}"),
            ["body"] = new OpenApiString("If you are reading this, outbound mail is working."),
        };
        example["isHtml"] = new OpenApiBoolean(false);
        schema.Example = example;

        if (schema.Properties.TryGetValue("to", out var toProperty))
        {
            toProperty.Example = new OpenApiString(to);
            toProperty.Description =
                $"Where to send it. Leave it out, or leave it as the example, to use the configured test recipient ({to}).";
        }
    }
}
