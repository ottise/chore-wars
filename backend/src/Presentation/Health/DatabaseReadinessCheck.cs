using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.Diagnostics.HealthChecks;
namespace ChoreWars.Presentation.Health;
public sealed class DatabaseReadinessCheck(IDatabaseSchemaStatus schema):IHealthCheck {
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context,CancellationToken cancellationToken=default)
        => (await schema.CheckAsync(cancellationToken)).Ready ? HealthCheckResult.Healthy() : HealthCheckResult.Unhealthy("Database schema is not ready.");
}
