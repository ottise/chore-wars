using ChoreWars.Infrastructure.Data;
using Microsoft.Extensions.Diagnostics.HealthChecks;
namespace ChoreWars.Presentation.Health;
public sealed class DatabaseReadinessCheck(AppDbContext db):IHealthCheck {
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context,CancellationToken cancellationToken=default)
        => await db.Database.CanConnectAsync(cancellationToken)?HealthCheckResult.Healthy():HealthCheckResult.Unhealthy("Database is unavailable.");
}
