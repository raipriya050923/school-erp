using SchoolErp.Api.Middleware;
using SchoolErp.Application;
using SchoolErp.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

const string CorsPolicy = "AngularClient";

// ----- Services -----
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Clean Architecture composition roots
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

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
            policy.WithOrigins(
                    builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
                    ?? new[] { "http://localhost:4200" })
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

app.UseCors(CorsPolicy);
app.MapControllers();
app.MapGet("/", () => Results.Ok(new { service = "SchoolErp Super Admin API", status = "running" }));

app.Run();
