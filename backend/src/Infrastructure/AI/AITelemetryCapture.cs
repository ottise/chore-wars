using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.AI;

public static class AITelemetryCapture
{
    public static async Task CaptureAsync(AppDbContext db, DateTime now, CancellationToken ct)
    {
        var batchId=Guid.NewGuid();
        var captured=new List<(Guid HouseId,OutboxMessage Message)>();
        db.ChangeTracker.DetectChanges();
        var activated = db.ChangeTracker.Entries<ChoreSeason>().Where(e=>e.State==EntityState.Modified && e.Entity.Status==SeasonStatus.ACTIVE && e.Property(x=>x.Status).OriginalValue!=SeasonStatus.ACTIVE).Select(e=>e.Entity).ToList();
        foreach (var season in activated)
        {
            var occurrences = await db.ChoreOccurrences.Include(o=>o.Responsibilities).Where(o=>o.SeasonId==season.Id && o.AssignedUserId!=null).ToListAsync(ct);
            foreach (var occurrence in occurrences.Where(o=>o.Status==ChoreOccurrenceStatus.ASSIGNED && o.Responsibilities.All(r=>r.EndedAt!=null))) {
                var episode=new ChoreResponsibility { Id=Guid.NewGuid(), OccurrenceId=occurrence.Id, UserId=occurrence.AssignedUserId!.Value, Reason="INITIAL", StartedAt=now, Deadline=occurrence.DueDate };
                occurrence.Responsibilities.Add(episode);
                db.Set<ChoreResponsibility>().Add(episode);
            }
        }
        db.ChangeTracker.DetectChanges();
        var changed = db.ChangeTracker.Entries().Where(e=>e.State is EntityState.Added or EntityState.Modified || e.State==EntityState.Deleted && e.Entity is MemberPreference or MemberAvailability or MemberAvailabilityException).Select(e=>e.Entity).ToList();
        foreach (var value in changed)
        {
            Guid houseId, id;
            string kind;
            object payload;
            switch (value)
            {
                case AIObservation observed:
                    if(db.Entry(observed).State!=EntityState.Added)continue;
                    houseId=observed.HouseId;id=observed.Id;kind="interaction";
                    payload=new{member_id=observed.UserId,season_id=observed.SeasonId,occurrence_id=observed.OccurrenceId,bounty_id=observed.BountyId,action=observed.Kind,recorded_at=observed.RecordedAt,interpretation="OPEN_SIGNAL_ONLY_NOT_READ_ACCEPTANCE_OR_PREFERENCE"};break;
                case ChatMessage message:
                    if (message.MessageType!="TEXT" || db.Entry(message).State!=EntityState.Added) continue;
                    var room=db.ChatRooms.Local.FirstOrDefault(r=>r.Id==message.RoomId) ?? await db.ChatRooms.SingleAsync(r=>r.Id==message.RoomId,ct);
                    var settings=await db.HouseAiSettings.SingleOrDefaultAsync(s=>s.HouseId==room.HouseId,ct);
                    var consent=await db.MemberAiConsents.SingleOrDefaultAsync(c=>c.HouseId==room.HouseId && c.UserId==message.SenderId,ct);
                    if (settings?.Enabled==true && settings.ChatAutoInsightsEnabled && consent?.ChatAnalysisEnabled==true)
                        db.AIChatInsights.Add(new AIChatInsight{Id=Guid.NewGuid(),HouseId=room.HouseId,UserId=message.SenderId,MessageId=message.Id,ConsentVersion=consent.Version,CreatedAt=now});
                    continue;
                case ChoreOccurrence o:
                    var chore = o.Chore ?? await db.Chores.FindAsync([o.ChoreId], ct) ?? throw new InvalidDataException("Occurrence chore missing.");
                    houseId=chore.HouseId; id=o.Id; kind="occurrence";
                    payload=new { occurrence_id=o.Id, season_id=o.SeasonId, template_id=chore.SourceTemplateId ?? o.ChoreId, name=chore.Name, minutes=o.SnapshotMinutes, karma=o.SnapshotKarma, due_at=o.DueDate, assigned_to=o.AssignedUserId, completed_by=o.CompletedByUserId, completed_at=o.CompletedAt, status=o.Status.ToString(), planned_start=o.PlannedStartAt };
                    break;
                case HouseMember member:
                    houseId=member.HouseId;id=member.Id;kind="member";
                    payload=new{member_id=member.UserId,status=member.Status.ToString(),role=member.Role.ToString(),joined_at=member.JoinedAt};break;
                case MemberAvailability availability:
                    var avSeason=db.Seasons.Local.FirstOrDefault(s=>s.Id==availability.SeasonId) ?? await db.Seasons.SingleAsync(s=>s.Id==availability.SeasonId,ct);
                    houseId=avSeason.HouseId;id=availability.Id;kind="availability";
                    payload=new{member_id=availability.UserId,season_id=availability.SeasonId,day=(int)availability.DayOfWeek,available=availability.IsAvailable,slots=availability.Slots.Select(s=>new{start=s.StartMinute,end=s.EndMinute}),effective_at=now,deleted=db.Entry(availability).State==EntityState.Deleted};break;
                case MemberAvailabilityException exception:
                    var exceptionSeason=db.Seasons.Local.FirstOrDefault(s=>s.Id==exception.SeasonId) ?? await db.Seasons.SingleAsync(s=>s.Id==exception.SeasonId,ct);
                    houseId=exceptionSeason.HouseId;id=exception.Id;kind="availability_exception";
                    payload=new{member_id=exception.UserId,season_id=exception.SeasonId,date=exception.LocalDate,slots=JsonSerializer.Deserialize<JsonElement>(exception.SlotsJson),effective_at=now,deleted=db.Entry(exception).State==EntityState.Deleted};break;
                case MemberPreference preference:
                    var preferredChore=db.Chores.Local.FirstOrDefault(c=>c.Id==preference.ChoreId) ?? await db.Chores.SingleAsync(c=>c.Id==preference.ChoreId,ct);
                    houseId=preferredChore.HouseId;id=preference.Id;kind="preference";
                    payload=new{member_id=preference.UserId,template_id=preference.ChoreId,history_template_id=preferredChore.SourceTemplateId ?? preferredChore.Id,chore_name=preferredChore.Name,type=preference.Type.ToString(),effective_at=now,deleted=db.Entry(preference).State==EntityState.Deleted};break;
                case SeasonRanking ranking:
                    var rankSeason=db.Seasons.Local.FirstOrDefault(s=>s.Id==ranking.SeasonId) ?? await db.Seasons.SingleAsync(s=>s.Id==ranking.SeasonId,ct);
                    var rankCount=db.SeasonRankings.Local.Count(r=>r.SeasonId==ranking.SeasonId);
                    if(rankCount==0)rankCount=await db.SeasonRankings.CountAsync(r=>r.SeasonId==ranking.SeasonId,ct);
                    houseId=rankSeason.HouseId;id=ranking.Id;kind="ranking";
                    payload=new{member_id=ranking.UserId,season_id=ranking.SeasonId,rank=ranking.Rank,member_count=rankCount,total_karma=ranking.TotalKarma,chores_completed=ranking.ChoresCompleted,finalized_at=now};break;
                case ChoreResponsibility e:
                    var occurrence = db.ChoreOccurrences.Local.FirstOrDefault(o=>o.Id==e.OccurrenceId) ?? await db.ChoreOccurrences.Include(o=>o.Chore).SingleAsync(o=>o.Id==e.OccurrenceId,ct);
                    var template = occurrence.Chore ?? await db.Chores.FindAsync([occurrence.ChoreId], ct) ?? throw new InvalidDataException("Episode chore missing.");
                    houseId=template.HouseId; id=e.Id; kind="episode";
                    var snapshot=db.AIResponsibilityContextSnapshots.Local.FirstOrDefault(s=>s.EpisodeId==e.Id) ?? await db.AIResponsibilityContextSnapshots.SingleOrDefaultAsync(s=>s.EpisodeId==e.Id,ct);
                    if (snapshot==null && e.Reason!="LEGACY" && db.Entry(e).State==EntityState.Added)
                    {
                        var house = db.Houses.Local.FirstOrDefault(h=>h.Id==houseId) ?? await db.Houses.SingleAsync(h=>h.Id==houseId,ct);
                        var av=await db.MemberAvailabilities.Include(a=>a.Slots).Where(a=>a.SeasonId==occurrence.SeasonId && a.UserId==e.UserId).ToListAsync(ct);
                        var constraints=await db.MemberConstraints.SingleOrDefaultAsync(c=>c.HouseId==houseId && c.UserId==e.UserId,ct);
                        var preferences=await db.MemberPreferences.Where(p=>p.UserId==e.UserId && p.Chore.HouseId==houseId).ToListAsync(ct);
                        var seasonTasks=await db.ChoreOccurrences.Where(o=>o.SeasonId==occurrence.SeasonId).ToListAsync(ct);
                        var assigned=db.ChoreOccurrences.Local.Where(o=>o.SeasonId==occurrence.SeasonId).Concat(seasonTasks).DistinctBy(o=>o.Id).Where(o=>o.AssignedUserId==e.UserId).ToList();
                        var completedHistory=await db.ChoreOccurrences.Include(o=>o.Chore).Where(o=>o.Chore.HouseId==houseId && o.CompletedByUserId==e.UserId && o.CompletedAt<e.StartedAt).ToListAsync(ct);
                        var persistedExceptions=await db.MemberAvailabilityExceptions.Where(x=>x.SeasonId==occurrence.SeasonId && x.UserId==e.UserId).ToListAsync(ct);
                        var dateExceptions=db.MemberAvailabilityExceptions.Local.Where(x=>x.SeasonId==occurrence.SeasonId && x.UserId==e.UserId && db.Entry(x).State!=EntityState.Deleted).Concat(persistedExceptions).DistinctBy(x=>x.Id).ToList();
                        var context=new { schema_version=AIConstants.SchemaVersion, house_id=houseId, episode_id=e.Id, member_id=e.UserId, occurrence_id=occurrence.Id,chore_id=occurrence.ChoreId,template_id=template.SourceTemplateId ?? template.Id,
                            prediction_time=e.StartedAt, deadline=e.Deadline, minutes=occurrence.SnapshotMinutes, karma=occurrence.SnapshotKarma, difficulty=occurrence.SnapshotDifficulty.ToString(), reason=e.Reason,
                            workload=assigned.Select(x=>new{x.Id,x.AssignedUserId,x.SnapshotMinutes,x.SnapshotKarma,x.DueDate,x.PlannedStartAt}).ToList(),
                            availability=av.Select(a=>new{day=(int)a.DayOfWeek,available=a.IsAvailable,slots=a.Slots.Select(s=>new{start=s.StartMinute,end=s.EndMinute})}),
                            preferences=preferences.Select(p=>new{template_id=p.ChoreId,type=p.Type.ToString()}),
                            date_exceptions=dateExceptions.ToDictionary(x=>x.LocalDate.ToString("yyyy-MM-dd"),x=>JsonSerializer.Deserialize<JsonElement>(x.SlotsJson)),
                            history=new{completed_count=completedHistory.Count,completed_standard_minutes=completedHistory.Sum(o=>o.SnapshotMinutes),same_template_completed=completedHistory.Count(o=>(o.Chore.SourceTemplateId ?? o.ChoreId)==(template.SourceTemplateId ?? template.Id))},
                            limits=new{max_chores_per_week=constraints?.MaxChoresPerWeek ?? AIAllocationConstants.DefaultMaxChoresPerWeek,max_minutes_per_day=constraints?.MaxEffortMinutesPerDay ?? AIAllocationConstants.DefaultMaxEffortMinutesPerDay} };
                        var json=JsonSerializer.Serialize(context);
                        snapshot=new AIResponsibilityContextSnapshot { Id=Guid.NewGuid(),HouseId=houseId,EpisodeId=e.Id,PredictionTime=e.StartedAt,CapturedAt=now,SourceSequence=house.AiTelemetrySequence+1,PayloadJson=json,ContextHash=Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json))) };
                        db.AIResponsibilityContextSnapshots.Add(snapshot);
                    }
                    payload=new { episode_id=e.Id,occurrence_id=e.OccurrenceId,season_id=occurrence.SeasonId,member_id=e.UserId,reason=e.Reason,started_at=e.StartedAt,deadline=e.Deadline,ended_at=e.EndedAt,completed_by=e.CompletedByUserId,snapshot_id=snapshot?.Id,source_snapshot=snapshot==null?(JsonElement?)null:JsonSerializer.Deserialize<JsonElement>(snapshot.PayloadJson) };
                    break;
                case ChoreBounty b:
                    var bo = db.ChoreOccurrences.Local.FirstOrDefault(o=>o.Id==b.ChoreOccurrenceId) ?? await db.ChoreOccurrences.Include(o=>o.Chore).SingleAsync(o=>o.Id==b.ChoreOccurrenceId,ct);
                    houseId=bo.Chore.HouseId;id=b.Id;kind="bounty";
                    payload=new {bounty_id=b.Id,occurrence_id=b.ChoreOccurrenceId,poster_id=b.PostedByUserId,amount=b.Amount,status=b.Status.ToString(),created_at=b.CreatedAt,expires_at=b.ExpiresAt};
                    break;
                case KarmaTransaction k:
                    houseId=k.HouseId;id=k.Id;kind="ledger";payload=new{member_id=k.UserId,season_id=k.SeasonId,amount=k.Amount,type=k.Type.ToString(),reference_id=k.ReferenceId,created_at=k.CreatedAt};break;
                case PaymentObligation p:
                    houseId=p.HouseId;id=p.Id;kind="payment";payload=new{occurrence_id=p.OccurrenceId,creditor_id=p.CreditorUserId,debtor_id=p.DebtorUserId,amount=p.Amount,status=p.Status.ToString(),confirmed_by=p.ConfirmedByUserId,paid_at=p.PaidAt};break;
                case ActionProposal p:
                    houseId=p.HouseId;id=p.Id;kind="proposal";payload=new{actor_id=p.CreatorId,type=p.Type.ToString(),status=p.Status.ToString(),requested_at=p.CreatedAt,payload=JsonSerializer.Deserialize<JsonElement>(p.PayloadJson)};break;
                case ChoreSeason s:
                    houseId=s.HouseId;id=s.Id;kind="season";payload=new{season_id=s.Id,status=s.Status.ToString(),revision=s.ScheduleRevision,start_at=s.StartDate,end_at=s.EndDate};break;
                default: continue;
            }
            var owner = db.Houses.Local.FirstOrDefault(h=>h.Id==houseId) ?? await db.Houses.SingleAsync(h=>h.Id==houseId,ct);
            owner.AiTelemetrySequence++;
            var eventId=Guid.NewGuid();
            var telemetryMessage=new OutboxMessage { Id=eventId,Topic=AIConstants.TelemetryTopic,MessageKey=houseId.ToString(),CreatedAt=now,
                Payload=JsonSerializer.Serialize(new{event_id=eventId,schema_version=AIConstants.SchemaVersion,house_id=houseId,house_sequence=owner.AiTelemetrySequence,event_type=kind+".upsert",entity_id=id,occurred_at=now,recorded_at=now,data_source=owner.AiDataSource,payload}) };
            db.OutboxMessages.Add(telemetryMessage);captured.Add((houseId,telemetryMessage));
        }
        foreach(var (houseId,message) in captured) {
            var envelope=JsonSerializer.Deserialize<Dictionary<string,JsonElement>>(message.Payload)!;
            envelope["capture_batch_id"]=JsonSerializer.SerializeToElement(batchId);
            envelope["batch_last_sequence"]=JsonSerializer.SerializeToElement(db.Houses.Local.Single(h=>h.Id==houseId).AiTelemetrySequence);
            message.Payload=JsonSerializer.Serialize(envelope);
        }
    }
}
