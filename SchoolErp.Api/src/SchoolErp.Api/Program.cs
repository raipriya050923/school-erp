using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using SchoolErp.Api.Middleware;
using SchoolErp.Application;
using SchoolErp.Application.Common;
using SchoolErp.Infrastructure;
using SchoolErp.Infrastructure.Services;

var builder = WebApplication.CreateBuilder(args);

const string CorsPolicy = "AngularClient";

// ----- Services -----
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    var scheme = new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Paste the token returned by POST /api/auth/login.",
        Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" },
    };
    options.AddSecurityDefinition("Bearer", scheme);
    options.AddSecurityRequirement(new OpenApiSecurityRequirement { [scheme] = Array.Empty<string>() });

    // Fills the mail-test example with the configured recipient, so Try it out works unedited.
    options.SchemaFilter<SchoolErp.Api.Swagger.TestEmailExampleFilter>();
});

// Clean Architecture composition roots
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

// Account provisioning knobs. Absent "Accounts" section => defaults => random passwords.
// "Accounts:FixedPassword" (set in appsettings.Development.json only) makes every generated
// login use that one password — a local convenience, never for a deployed environment.
builder.Services.AddSingleton(
    builder.Configuration.GetSection("Accounts").Get<AccountOptions>() ?? new AccountOptions());

// ----- Authentication -----
// Tokens are issued by JwtTokenService; JwtOptions is the single source of truth for the
// signing key so the issuer and this validator can never drift apart.
var jwt = JwtOptions.From(builder.Configuration);
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = jwt.SigningKey,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
builder.Services.AddAuthorization();

// CORS. Cors:AllowAll=true opens the API to any origin, which is for local work
// only; otherwise it is restricted to the Cors:AllowedOrigins list.
//
// Both branches used to call AllowAnyOrigin(), so AllowAll=false restricted
// nothing and the configured list was never read. Anything that relied on that
// will now be refused unless its origin is listed.
var allowAll = builder.Configuration.GetValue("Cors:AllowAll", false);
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? Array.Empty<string>();

// An origin is scheme + host + port and never ends in a slash. Browsers send it
// that way and the comparison is exact, so "https://site.com/" in config would
// silently match nothing — trimmed here rather than left as a trap.
allowedOrigins = allowedOrigins
    .Select(o => o.Trim().TrimEnd('/'))
    .Where(o => o.Length > 0)
    .Distinct(StringComparer.OrdinalIgnoreCase)
    .ToArray();

builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicy, policy =>
    {
        if (allowAll || allowedOrigins.Length == 0)
        {
            // No list configured is treated as "not configured yet" rather than
            // "block everything", so a missing setting cannot take an API down.
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
        }
        else
        {
            policy.WithOrigins(allowedOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod();
            // No AllowCredentials: the browser clients authenticate with a
            // bearer token in a header, not a cookie, so granting it would
            // widen the policy for nothing.
        }
    });
});

var app = builder.Build();

// ----- Pipeline -----
app.UseMiddleware<ExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Uploaded payment screenshots are served from wwwroot; nothing else is exposed statically.
app.UseStaticFiles();

app.UseCors(CorsPolicy);
app.UseAuthentication();
app.UseAuthorization();
// After authentication, so the claim is there to read; before the endpoints, so a user still on
// an issued password cannot reach one.
app.UseMiddleware<PasswordChangeRequiredMiddleware>();
app.MapControllers();
app.MapGet("/", () => Results.Ok(new { service = "SchoolErp Super Admin API V2", status = "running" }));

// Blocks until the host is told to stop. Without it the program configures the whole pipeline
// and then falls off the end of the file, which looks exactly like a clean exit: code 0, no
// output, nothing listening.
app.Run();

