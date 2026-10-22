namespace ChoreWars.Application.DTOs.AI;

public sealed class AIObservationRequest
{
    public Guid ClientRequestId { get; set; }
    public Guid EntityId { get; set; }
    public string Kind { get; set; } = "";
}
