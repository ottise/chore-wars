using ChoreWars.Application.DTOs.Deployment;

namespace ChoreWars.Application.Interfaces.Services;

public interface IDependencyHealthService
{
    Task<IReadOnlyList<DependencyStatusResponse>> CheckAsync(CancellationToken ct = default);
}
