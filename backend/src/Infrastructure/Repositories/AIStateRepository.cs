using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.Repositories;

public sealed class AIStateRepository(AppDbContext db) : IAIStateRepository
{
    public Task<AIObservation?> ObservationRequestAsync(Guid house,Guid actor,Guid request,CancellationToken ct)=>db.AIObservations.SingleOrDefaultAsync(o=>o.HouseId==house && o.UserId==actor && o.ClientRequestId==request,ct);
    public void AddObservation(AIObservation value)=>db.AIObservations.Add(value);
    public Task<HouseAiSettings?> SettingsAsync(Guid house, CancellationToken ct) => db.HouseAiSettings.SingleOrDefaultAsync(x=>x.HouseId==house,ct);
    public Task<MemberAiConsent?> ConsentAsync(Guid house, Guid user, CancellationToken ct) => db.MemberAiConsents.SingleOrDefaultAsync(x=>x.HouseId==house && x.UserId==user,ct);
    public Task<AIRecommendation?> RecommendationAsync(Guid id, CancellationToken ct) => db.AIRecommendations.SingleOrDefaultAsync(x=>x.Id==id,ct);
    public Task<AIRecommendation?> FindRequestAsync(Guid house, Guid actor, Guid request, CancellationToken ct) => db.AIRecommendations.SingleOrDefaultAsync(x=>x.HouseId==house && x.ActorId==actor && x.ClientRequestId==request,ct);
    public async Task<IReadOnlyList<MemberAvailabilityException>> AvailabilityExceptionsAsync(Guid season, CancellationToken ct) => await db.MemberAvailabilityExceptions.Where(x=>x.SeasonId==season).ToListAsync(ct);
    public Task<AIResponsibilityContextSnapshot?> SnapshotAsync(Guid id, CancellationToken ct) => db.AIResponsibilityContextSnapshots.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id,ct);
    public void AddSettings(HouseAiSettings value) => db.HouseAiSettings.Add(value);
    public void AddConsent(MemberAiConsent value) => db.MemberAiConsents.Add(value);
    public void AddRecommendation(AIRecommendation value) => db.AIRecommendations.Add(value);
    public void AddAvailabilityException(MemberAvailabilityException value) => db.MemberAvailabilityExceptions.Add(value);
    public Task<ChoreEvidence?> EvidenceAsync(Guid id, CancellationToken ct) => db.ChoreEvidence.SingleOrDefaultAsync(e=>e.Id==id,ct);
    public Task<ChoreEvidence?> EvidenceRequestAsync(Guid occurrence, Guid actor, Guid request, CancellationToken ct) => db.ChoreEvidence.SingleOrDefaultAsync(e=>e.OccurrenceId==occurrence && e.UploadedByUserId==actor && e.ClientRequestId==request,ct);
    public void AddEvidence(ChoreEvidence value) => db.ChoreEvidence.Add(value);
    public async Task<IReadOnlyList<AIChatInsight>> ChatInsightsAsync(Guid house, Guid actor, CancellationToken ct) => await db.AIChatInsights.Where(x=>x.HouseId==house && x.UserId==actor).OrderByDescending(x=>x.CreatedAt).Take(50).ToListAsync(ct);
    public async Task RevokeChatInsightsAsync(Guid house, Guid? actor, CancellationToken ct) {
        var items=await db.AIChatInsights.Where(x=>x.HouseId==house && (actor==null || x.UserId==actor)).ToListAsync(ct);
        db.AIChatInsights.RemoveRange(items);
    }
    public async Task<IReadOnlyList<Guid>> OwnOpenEpisodesAsync(Guid house, Guid actor, DateTime now, CancellationToken ct) => await db.Set<ChoreResponsibility>()
        .Where(e=>e.UserId==actor && e.EndedAt==null && e.Deadline>now && db.ChoreOccurrences.Any(o=>o.Id==e.OccurrenceId && o.Chore.HouseId==house && o.AssignedUserId==actor && o.Season.Status==ChoreWars.Domain.Enums.SeasonStatus.ACTIVE))
        .OrderBy(e=>e.Deadline).Select(e=>e.Id).Take(100).ToListAsync(ct);
}
