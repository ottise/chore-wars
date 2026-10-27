namespace ChoreWars.Application.DTOs.Deployment;

public sealed record DependencyStatusResponse(string Name, string State, string ReasonCode, DateTimeOffset CheckedAt);
