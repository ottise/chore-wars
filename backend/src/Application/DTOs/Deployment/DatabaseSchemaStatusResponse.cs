namespace ChoreWars.Application.DTOs.Deployment;

public sealed record DatabaseSchemaStatusResponse(bool Connected, bool Ready, string ReasonCode,
    IReadOnlyList<string> MissingMigrations, IReadOnlyList<string> MissingTables);
