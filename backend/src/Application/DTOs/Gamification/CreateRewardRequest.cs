namespace ChoreWars.Application.DTOs.Gamification;
public record CreateRewardRequest(string Name, string Description, int Cost);
public record UpdateRewardRequest(string Name, string Description, int Cost, bool Enabled);
public record CustomRewardResponse(Guid Id, string Name, string Description, int Cost, bool Enabled);
