using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Hosting;
using ChoreWars.Presentation.Extensions;
using System.IO;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsDevelopment())
{
    builder.Configuration
        .AddJsonFile("appsettings.AI.local.json", optional: true, reloadOnChange: true)
        .AddJsonFile("appsettings.Supplies.local.json", optional: true, reloadOnChange: true)
        .AddJsonFile("appsettings.OrderEmail.local.json", optional: true, reloadOnChange: true)
        .AddJsonFile("appsettings.Google.local.json", optional: true, reloadOnChange: true)
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
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (rejection, ct) =>
    {
        rejection.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        var seconds = rejection.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter)
            ? Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds)) : 60;
        rejection.HttpContext.Response.Headers.RetryAfter = seconds.ToString(System.Globalization.CultureInfo.InvariantCulture);
        await rejection.HttpContext.Response.WriteAsJsonAsync(new Microsoft.AspNetCore.Mvc.ProblemDetails
        {
            Status = StatusCodes.Status429TooManyRequests, Title = "Too many requests",
            Detail = $"Too many attempts. Please wait {seconds} seconds before trying again."
        }, cancellationToken: ct);
    };
    options.AddPolicy("password-auth", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 20, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    options.AddPolicy("email-otp", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    options.AddPolicy("google-auth", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});
builder.Services.Configure<ChoreWars.Presentation.Health.DeploymentHealthOptions>(builder.Configuration.GetSection("DeploymentHealth"));
builder.Services.AddSwaggerDocumentation();
builder.Services.AddInfrastructureServices(builder.Configuration);
builder.Services.PostConfigure<ChoreWars.Infrastructure.Storage.MediaStorageOptions>(options =>
{
    if (!Path.IsPathRooted(options.RootPath))
        options.RootPath = Path.Combine(builder.Environment.ContentRootPath, options.RootPath);
});
builder.Services.AddApplicationServices();
builder.Services.AddHealthChecks().AddCheck<ChoreWars.Presentation.Health.DatabaseReadinessCheck>("database",tags:new[]{"ready"});
builder.Services.AddJwtAuthentication(builder.Configuration);

var app = builder.Build();

if (int.TryParse(builder.Configuration["PORT"], out var port) && port is > 0 and <= 65535)
{
    app.Urls.Clear();
    app.Urls.Add($"http://0.0.0.0:{port}");
}

// Configure the HTTP request pipeline.
app.UseSwaggerDocumentation(app.Environment);

app.UseCustomMiddleware();

app.UseStaticFiles();

// app.UseHttpsRedirection();

app.UseCors();

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapPresentationEndpoints();
app.MapHealthChecks("/health/live",new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions{Predicate=_=>false});
app.MapHealthChecks("/health/ready",new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions{Predicate=check=>check.Tags.Contains("ready")});

app.Run();

public partial class Program { }
