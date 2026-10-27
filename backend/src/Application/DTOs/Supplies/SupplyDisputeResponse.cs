namespace ChoreWars.Application.DTOs.Supplies;
public sealed record SupplyDisputeResponse(Guid Id,Guid CreatorUserId,Guid? ProductId,string Reason,string? Resolution,DateTime CreatedAt,DateTime? ProposedAt,DateTime? AcceptedAt);
