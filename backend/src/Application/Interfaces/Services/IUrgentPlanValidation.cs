using ChoreWars.Application.DTOs.Proposal;

namespace ChoreWars.Application.Interfaces.Services;

public interface IUrgentPlanValidation
{
    Task ValidateAsync(Guid house, UrgentEventPayload payload, CancellationToken ct);
}
