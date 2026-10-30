namespace ChoreWars.Application.DTOs.Season;

public record RedistributionChange(Guid OccurrenceId, string ChoreName, Guid? FromUserId, Guid ToUserId, DateTime PlannedStartAt, DateTime DueAt);
public record RedistributionResult(Guid HouseId, Guid SeasonId, Guid TargetUserId, int BaseRevision, int Revision,
    string ContextHash, List<RedistributionChange> Changes, List<string> Reasons)
{
    public int MovedCount => Changes.Count(c => c.FromUserId.HasValue);
    public int AssignedCount => Changes.Count;
}
public record ConfirmRedistributionRequest(Guid TargetUserId, int ExpectedRevision, string ContextHash, Guid ClientRequestId);
