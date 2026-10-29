namespace ChoreWars.Application.Interfaces.Services;

public interface IMembershipChoreRedistributor
{
    // Called inside the join transaction and household mutation lock.
    Task RedistributeAsync(Guid houseId, Guid newUserId, CancellationToken ct);
}
