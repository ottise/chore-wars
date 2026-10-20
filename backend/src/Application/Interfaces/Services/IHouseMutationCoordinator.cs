namespace ChoreWars.Application.Interfaces.Services;
/// Serializes a household mutation and commits its data and events together.
public interface IHouseMutationCoordinator {
    Task RunAsync(Guid houseId, Func<Task> action, CancellationToken ct = default);
    Task<T> RunAsync<T>(Guid houseId, Func<Task<T>> action, CancellationToken ct = default);
}
