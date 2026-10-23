using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Hosting;
using ChoreWars.Presentation.Extensions;
using System.IO;

var builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsDevelopment())
{
    builder.Configuration
        .AddJsonFile("appsettings.AI.local.json", optional: true, reloadOnChange: true)
        .AddEnvironmentVariables()
        .AddCommandLine(args);
}

// The Windows Event Log provider requires elevated permissions and can throw
// while handling an otherwise normal API error, which aborts the HTTP response.
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

// Keep development keys with the application instead of the Windows profile.
// This avoids stale/inaccessible DPAPI keys when switching between Visual
// Studio, CLI, and Docker hosts.
builder.Services.AddDataProtection()
    .SetApplicationName("ChoreWars")
    .PersistKeysToFileSystem(new DirectoryInfo(
        Path.Combine(builder.Environment.ContentRootPath, ".data-protection-keys")));

// Add services to the container.
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});
builder.Services.AddPresentationServices();
builder.Services.AddSwaggerDocumentation();
builder.Services.AddInfrastructureServices(builder.Configuration);
builder.Services.AddApplicationServices();
builder.Services.AddHealthChecks().AddCheck<ChoreWars.Presentation.Health.DatabaseReadinessCheck>("database",tags:new[]{"ready"});
builder.Services.AddJwtAuthentication(builder.Configuration);

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseSwaggerDocumentation(app.Environment);

app.UseCustomMiddleware();

app.UseStaticFiles();

// app.UseHttpsRedirection();

app.UseCors();

app.UseAuthentication();
app.UseAuthorization();

app.MapPresentationEndpoints();
app.MapHealthChecks("/health/live",new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions{Predicate=_=>false});
app.MapHealthChecks("/health/ready",new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions{Predicate=check=>check.Tags.Contains("ready")});

app.Run();

public partial class Program { }
