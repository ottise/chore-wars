using ChoreWars.Application.DTOs.Deployment;

namespace ChoreWars.Application.Interfaces.Services;

public interface IDatabaseSchemaStatus
{
    Task<DatabaseSchemaStatusResponse> CheckAsync(CancellationToken ct = default);
}
