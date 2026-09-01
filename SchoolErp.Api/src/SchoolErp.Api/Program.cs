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

// CORS. By default allow any origin (set Cors:AllowAll=false to restrict to the
// configured Cors:AllowedOrigins list instead).
var allowAll = builder.Configuration.GetValue("Cors:AllowAll", true);
builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicy, policy =>
    {
        if (allowAll)
        {
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
        }
        else
        {
            policy.AllowAnyOrigin()
                .AllowAnyHeader()
                .AllowAnyMethod();
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
app.MapControllers();
app.MapGet("/", () => Results.Ok(new { service = "SchoolErp Super Admin API", status = "running" }));

app.Run();
