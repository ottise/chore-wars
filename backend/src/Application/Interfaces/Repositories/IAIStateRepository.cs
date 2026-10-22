using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IAIStateRepository
{
    Task<HouseAiSettings?> SettingsAsync(Guid houseId, CancellationToken ct);
    Task<MemberAiConsent?> ConsentAsync(Guid houseId, Guid userId, CancellationToken ct);
    Task<AIRecommendation?> RecommendationAsync(Guid id, CancellationToken ct);
    Task<AIRecommendation?> FindRequestAsync(Guid houseId, Guid actorId, Guid requestId, CancellationToken ct);
    Task<IReadOnlyList<MemberAvailabilityException>> AvailabilityExceptionsAsync(Guid seasonId, CancellationToken ct);
    Task<AIResponsibilityContextSnapshot?> SnapshotAsync(Guid id, CancellationToken ct);
    Task<ChoreEvidence?> EvidenceAsync(Guid id, CancellationToken ct);
    Task<ChoreEvidence?> EvidenceRequestAsync(Guid occurrence, Guid actor, Guid requestId, CancellationToken ct);
    void AddSettings(HouseAiSettings value);
    void AddConsent(MemberAiConsent value);
    void AddRecommendation(AIRecommendation value);
    void AddAvailabilityException(MemberAvailabilityException value);
    void AddEvidence(ChoreEvidence value);
    Task<IReadOnlyList<AIChatInsight>> ChatInsightsAsync(Guid house, Guid actor, CancellationToken ct);
    Task RevokeChatInsightsAsync(Guid house, Guid? actor, CancellationToken ct);
    Task<IReadOnlyList<Guid>> OwnOpenEpisodesAsync(Guid house, Guid actor, DateTime now, CancellationToken ct);
    Task<AIObservation?> ObservationRequestAsync(Guid house, Guid actor, Guid request, CancellationToken ct);
    void AddObservation(AIObservation value);
}
