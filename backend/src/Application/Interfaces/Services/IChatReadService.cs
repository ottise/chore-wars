namespace ChoreWars.Application.Interfaces.Services;

public interface IChatReadService
{
    Task<int> UnreadAsync(Guid house, Guid actor, CancellationToken ct);
    Task ReadAsync(Guid house, Guid actor, Guid messageId, CancellationToken ct);
}
