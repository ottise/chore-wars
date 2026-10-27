namespace ChoreWars.Application.DTOs.Supplies;
public sealed record OrderCostShareResponse(Guid UserId, string DisplayName, decimal Amount, bool Approved, bool Rejected);
