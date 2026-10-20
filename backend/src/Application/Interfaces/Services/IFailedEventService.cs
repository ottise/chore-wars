namespace ChoreWars.Application.Interfaces.Services;

public record FailedEventItem(Guid Id, string Topic, string Status, string ErrorCode, int FailureCount,
    DateTime FirstFailedAt, DateTime LastFailedAt, DateTime? ResolvedAt, int ReplayCount);
public record FailedEventPage(IReadOnlyList<FailedEventItem> Items, int Total, int Page, int PageSize);
public interface IFailedEventService
{
    Task<FailedEventPage> ListAsync(Guid houseId, Guid userId, string? status, int page, CancellationToken ct);
    Task ReplayAsync(Guid houseId, Guid failedEventId, Guid userId, CancellationToken ct);
}
