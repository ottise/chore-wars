namespace ChoreWars.Application.DTOs.Deployment;

public sealed record DeploymentHealthResponse(string Version, IReadOnlyList<DependencyStatusResponse> Components);
