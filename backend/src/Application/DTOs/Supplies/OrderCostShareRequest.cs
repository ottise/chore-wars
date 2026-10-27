namespace ChoreWars.Application.DTOs.Supplies;
public sealed record OrderCostShareRequest(Guid UserId, decimal? Amount = null);
