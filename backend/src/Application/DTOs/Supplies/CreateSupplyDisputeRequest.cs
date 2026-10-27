namespace ChoreWars.Application.DTOs.Supplies;
public sealed record CreateSupplyDisputeRequest(Guid ClientRequestId,string Reason,Guid? ProductId=null);
