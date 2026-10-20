namespace ChoreWars.Application.Interfaces.Services;
public interface IHouseAccessService {
    Task EnsureWritableAsync(Guid houseId, CancellationToken ct);
    Task EnsureActiveAsync(Guid houseId, Guid userId, CancellationToken ct);
    Task EnsureEntityScopeAsync(Guid houseId, string kind, Guid entityId, CancellationToken ct);
}
