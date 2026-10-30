using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using FluentValidation;

namespace ChoreWars.Application.Services.AI;

public sealed class AIHousekeeperService(IUnitOfWork uow, IAIStateRepository ai, IAIHousekeeperClient client,
    IAIContextBuilder contexts, IHouseMutationCoordinator mutations, IHouseAccessService access, TimeProvider clock,
    IActionProposalService proposals, IScheduleChangeService scheduleChanges,
    IValidator<AIGenerateRequest> generateValidator, IValidator<AITextRequest> textValidator,
    IValidator<AIAvailabilityChangeRequest> availabilityValidator, IValidator<AIObservationRequest> observationValidator,
    IAIServiceStatus? serviceStatus = null) : IAIHousekeeperService
{
    private async Task AuthorizeAsync(Guid house, Guid actor, bool owner, CancellationToken ct)
    {
        await access.EnsureActiveAsync(house,actor,ct);
        if (owner && (await uow.HouseMembers.GetByHouseAndUserIdAsync(house,actor,ct))?.Role!=HouseRole.OWNER)
            throw new ForbiddenException("Only the active household owner may access this AI operation.");
    }

    public Task<JsonElement> ObserveAsync(Guid house,Guid actor,AIObservationRequest request,CancellationToken ct)=>mutations.RunAsync(house,async()=> {
        await AuthorizeAsync(house,actor,false,ct);
        var validation=await observationValidator.ValidateAsync(request,ct);
        if(!validation.IsValid)throw new ChoreWars.Domain.Exceptions.ValidationException(validation.Errors.GroupBy(e=>e.PropertyName).ToDictionary(g=>g.Key,g=>g.Select(e=>e.ErrorMessage).ToArray()));
        var old=await ai.ObservationRequestAsync(house,actor,request.ClientRequestId,ct);
        if(old!=null) {
            if(old.Kind!=request.Kind || (old.BountyId ?? old.OccurrenceId)!=request.EntityId)throw new ConflictException("Observation request ID already has different input.");
            return JsonSerializer.SerializeToElement(new{recorded=true,id=old.Id});
        }
        if((await ai.SettingsAsync(house,ct))?.Enabled!=true)return JsonSerializer.SerializeToElement(new{recorded=false,reason="AI_DISABLED"});
        var occurrenceId=request.EntityId;
        if(request.Kind==AIObservationKinds.BountyOpened) {
            var bounty=await uow.ChoreBounties.GetByIdAsync(request.EntityId,ct) ?? throw new NotFoundException("Bounty not found.");
            occurrenceId=bounty.ChoreOccurrenceId;
        }
        var occurrence=await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,ct) ?? throw new NotFoundException("Task not found.");
        if(occurrence.Chore.HouseId!=house)throw new NotFoundException("Observation entity not in household.");
        var value=new AIObservation{Id=Guid.NewGuid(),HouseId=house,UserId=actor,ClientRequestId=request.ClientRequestId,Kind=request.Kind,OccurrenceId=occurrenceId,SeasonId=occurrence.SeasonId,BountyId=request.Kind==AIObservationKinds.BountyOpened?request.EntityId:null,RecordedAt=clock.GetUtcNow().UtcDateTime};
        ai.AddObservation(value);return JsonSerializer.SerializeToElement(new{recorded=true,id=value.Id});
    },ct);

    public async Task<JsonElement> ReadAsync(Guid house, Guid actor, string path, bool ownerOnly, CancellationToken ct)
    {
        await AuthorizeAsync(house,actor,ownerOnly,ct);
        var result=await client.GetAsync(house,actor,$"/v1/houses/{house}/{path}",ct);
        return await mutations.RunAsync(house,async()=> { await AuthorizeAsync(house,actor,ownerOnly,ct);return result; },ct);
    }

    public Task<JsonElement> SettingsAsync(Guid house, Guid actor, bool? enabled, bool? chatAuto, CancellationToken ct)
        => mutations.RunAsync(house,async()=> {
            await AuthorizeAsync(house,actor,enabled.HasValue || chatAuto.HasValue,ct);
            var settings=await ai.SettingsAsync(house,ct);
            if (settings==null) { settings=new HouseAiSettings{HouseId=house}; if (enabled.HasValue||chatAuto.HasValue) ai.AddSettings(settings); }
            if (enabled.HasValue || chatAuto.HasValue) {
                await access.EnsureWritableAsync(house,ct);
                settings.Enabled=enabled ?? settings.Enabled; settings.ChatAutoInsightsEnabled=chatAuto ?? settings.ChatAutoInsightsEnabled; settings.Version++;
                if (!settings.Enabled || !settings.ChatAutoInsightsEnabled) await ai.RevokeChatInsightsAsync(house,null,ct);
            }
            return JsonSerializer.SerializeToElement(new{enabled=settings.Enabled,configured=serviceStatus?.IsConfigured ?? true,chat_auto_insights_enabled=settings.ChatAutoInsightsEnabled,version=settings.Version});
        },ct);

    public Task<JsonElement> ConsentAsync(Guid house, Guid actor, bool? enabled, CancellationToken ct)
        => mutations.RunAsync(house,async()=> {
            await AuthorizeAsync(house,actor,false,ct);
            var consent=await ai.ConsentAsync(house,actor,ct);
            if (consent==null) { consent=new MemberAiConsent{HouseId=house,UserId=actor}; if (enabled.HasValue) ai.AddConsent(consent); }
            if (enabled.HasValue) { consent.ChatAnalysisEnabled=enabled.Value; consent.Version++; consent.UpdatedAt=clock.GetUtcNow().UtcDateTime; if(!enabled.Value) await ai.RevokeChatInsightsAsync(house,actor,ct); }
            return JsonSerializer.SerializeToElement(new{chat_analysis_enabled=consent.ChatAnalysisEnabled,version=consent.Version});
        },ct);

    public Task<JsonElement> GenerateAsync(Guid house, Guid actor, AIGenerateRequest request, CancellationToken ct)
        => GenerateCoreAsync(house,actor,request,ct);

    public async Task<JsonElement> RequestUrgentAsync(Guid house, Guid actor, AIGenerateRequest request, CancellationToken ct)
    {
        request.Kind=AIConstants.Urgent;
        var plan=await GenerateAsync(house,actor,request,ct);
        if (plan.GetProperty("result").TryGetProperty("status",out var status) && status.GetString()==AIConstants.Ready)
            return await AcceptAsync(house,actor,plan.GetProperty("id").GetGuid(),ct);
        return plan;
    }

    private async Task<JsonElement> GenerateCoreAsync(Guid house, Guid actor, AIGenerateRequest request, CancellationToken ct, string? confirmationHash=null)
    {
        var validation=await generateValidator.ValidateAsync(request,ct);
        if(!validation.IsValid)throw new ChoreWars.Domain.Exceptions.ValidationException(validation.Errors.GroupBy(e=>e.PropertyName).ToDictionary(g=>g.Key,g=>g.Select(e=>e.ErrorMessage).ToArray()));
        if (request.ClientRequestId==Guid.Empty || request.SeasonId==Guid.Empty || request.Kind is not (AIConstants.Allocation or AIConstants.Replan or AIConstants.Swap or AIConstants.Evolution or AIConstants.Urgent))
            throw new DomainException("A request ID, season, and supported recommendation kind are required.");
        JsonElement context=default;
        var deadlineMinutes=request.DeadlineMinutes;
        bool create=false;
        var record=await mutations.RunAsync(house,async()=> {
            await AuthorizeAsync(house,actor,request.Kind is AIConstants.Allocation or AIConstants.Evolution,ct); await access.EnsureWritableAsync(house,ct);
            if (request.Kind!=AIConstants.Urgent && (await ai.SettingsAsync(house,ct))?.Enabled!=true) throw new ConflictException("Enable AI for this household first.");
            var inputHash=confirmationHash ?? Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(request))));
            var old=await ai.FindRequestAsync(house,actor,request.ClientRequestId,ct);
            if (old!=null) { if (old.InputHash!=inputHash) throw new ConflictException("Request ID already used with different input."); return old; }
            context=await contexts.BuildAsync(house,request.SeasonId,ct);
            if (request.Kind==AIConstants.Urgent && request.ReadyBy.HasValue) {
                var remaining=(request.ReadyBy.Value-context.GetProperty("as_of").GetDateTimeOffset()).TotalMinutes;
                if (remaining<=0 || remaining>AIConstants.UrgentMaxDeadlineMinutes) throw new DomainException("Choose a future urgent deadline within 48 hours.");
                deadlineMinutes=(int)Math.Ceiling(remaining);
            }
            var originalContextHash=contexts.Fingerprint(context);
            if(request.ExpectedContextHash!=null && request.ExpectedContextHash!=originalContextHash)throw new ConflictException("Schedule changed while preparing availability; review it again.");
            if(request.AvailabilityChanges.Count>0) {
                if(request.Kind!=AIConstants.Replan || request.AvailabilityChanges.Any(c=>c.UserId!=actor))throw new ForbiddenException("Only your own availability may be proposed through AI replan.");
                context=await scheduleChanges.CandidateContextAsync(house,request.SeasonId,context,request.AvailabilityChanges,ct);
            }
            if(request.Kind==AIConstants.Urgent && (string.IsNullOrWhiteSpace(request.Text) || request.Text.Length>8000 || deadlineMinutes is <1 or >AIConstants.UrgentMaxDeadlineMinutes || request.GuestCount is <1 or >10000 || !request.ParticipantIds.Contains(actor) || request.ParticipantIds.Count<2 || request.ParticipantIds.Distinct().Count()!=request.ParticipantIds.Count || request.Resources.Count>30))throw new DomainException("Urgent planning needs text, a deadline and at least two distinct participants including yourself.");
            var expected=request.Kind is AIConstants.Allocation or AIConstants.Evolution?AIConstants.Draft:"ACTIVE";
            if (context.GetProperty("status").GetString()!=expected) throw new ConflictException($"This recommendation requires a {expected} season.");
            if (request.Kind==AIConstants.Swap) {
                var source=context.GetProperty("tasks").EnumerateArray().FirstOrDefault(t=>t.GetProperty("id").GetGuid()==request.SourceOccurrenceId);
                if (source.ValueKind==JsonValueKind.Undefined || source.GetProperty("assigned_to").ValueKind==JsonValueKind.Null || source.GetProperty("assigned_to").GetGuid()!=actor || source.GetProperty("locked").GetBoolean()) throw new ForbiddenException("Select an unlocked responsibility assigned to yourself.");
            }
            if (request.Kind==AIConstants.Evolution) {
                var previous=request.SourceSeasonId.HasValue?await uow.Seasons.GetByIdAsync(request.SourceSeasonId.Value,ct):null;
                if (previous?.HouseId!=house || previous.Status!=SeasonStatus.COMPLETED) throw new ConflictException("Evolution needs a completed source season from this household.");
            }
            var next=new AIRecommendation{Id=Guid.NewGuid(),HouseId=house,ActorId=actor,SeasonId=request.SeasonId,ClientRequestId=request.ClientRequestId,
                Kind=request.Kind,InputHash=inputHash,ContextHash=originalContextHash,AvailabilityChangesJson=JsonSerializer.Serialize(request.AvailabilityChanges),Status=AIConstants.Generating,CreatedAt=clock.GetUtcNow().UtcDateTime,ExpiresAt=clock.GetUtcNow().UtcDateTime.AddMinutes(request.Kind==AIConstants.Urgent?5:AIConstants.RecommendationLifetimeMinutes)};
            ai.AddRecommendation(next); create=true; return next;
        },ct);
        if (!create) return View(record);
        try
        {
            var body=new Dictionary<string,object?>{["context"]=context,["history_enabled"]=true,["mode"]="SERVING_DEADLINE"};
            if (request.Kind==AIConstants.Swap) body["source_occurrence_id"]=request.SourceOccurrenceId;
            if (request.Kind==AIConstants.Urgent) body=new(){["context"]=context,["text"]=request.Text,["deadline_minutes"]=deadlineMinutes,["ready_by"]=request.ReadyBy,["guest_count"]=request.GuestCount,["participant_ids"]=request.ParticipantIds,["resources"]=request.Resources};
            var path=request.Kind switch { AIConstants.Replan=>"/v1/schedules/replan",AIConstants.Swap=>"/v1/schedules/swap",AIConstants.Evolution=>"/v1/seasons/evolve",AIConstants.Urgent=>"/v1/urgent/plan",_=>"/v1/schedules/propose" };
            var result=await client.PostAsync(house,actor,path,body,ct);
            return await mutations.RunAsync(house,async()=> {
                await AuthorizeAsync(house,actor,request.Kind is AIConstants.Allocation or AIConstants.Evolution,ct);
                if (request.Kind!=AIConstants.Urgent && (await ai.SettingsAsync(house,ct))?.Enabled!=true) throw new ConflictException("AI was disabled during inference.");
                var current=await ai.RecommendationAsync(record.Id,ct) ?? throw new NotFoundException("Recommendation not found.");
                current.PayloadJson=result.GetRawText(); current.Status=AIConstants.Ready;
                return View(current);
            },ct);
        }
        catch
        {
            await mutations.RunAsync(house,async()=> {
                var current=await ai.RecommendationAsync(record.Id,CancellationToken.None);
                if (current!=null) current.Status=AIConstants.Failed;
            },CancellationToken.None);
            throw;
        }
    }

    private async Task<AIRecommendation> GetAsync(Guid house, Guid actor, Guid id, CancellationToken ct)
    {
        await AuthorizeAsync(house,actor,false,ct);
        var value=await ai.RecommendationAsync(id,ct) ?? throw new NotFoundException("Recommendation not found.");
        if (value.HouseId!=house || value.ActorId!=actor) throw new NotFoundException("Recommendation not found.");
        if (value.Kind is AIConstants.Allocation or AIConstants.Evolution) await AuthorizeAsync(house,actor,true,ct);
        return value;
    }

    public async Task<JsonElement> RecommendationAsync(Guid house, Guid actor, Guid id, CancellationToken ct) {
        var value=await GetAsync(house,actor,id,ct);
        var result=View(value).EnumerateObject().ToDictionary(p=>p.Name,p=>p.Value);
        if(value.ProposalId.HasValue) {
            var linked=await uow.ActionProposals.GetByIdAsync(value.ProposalId.Value,ct);
            if(linked!=null)result["proposal_status"]=JsonSerializer.SerializeToElement(linked.Status.ToString());
        }
        return JsonSerializer.SerializeToElement(result);
    }

    public Task<JsonElement> RejectAsync(Guid house, Guid actor, Guid id, CancellationToken ct) => mutations.RunAsync(house,async()=> {
        var value=await GetAsync(house,actor,id,ct);
        if (value.Status==AIConstants.Applied) throw new ConflictException("An applied recommendation cannot be rejected.");
        value.Status=AIConstants.Rejected; return View(value);
    },ct);

    public Task<JsonElement> AcceptAsync(Guid house, Guid actor, Guid id, CancellationToken ct) => mutations.RunAsync(house,async()=> {
        var value=await GetAsync(house,actor,id,ct);
        if (value.Status==AIConstants.Applied || value.ProposalId.HasValue) return View(value);
        await access.EnsureWritableAsync(house,ct);
        if (value.Kind!=AIConstants.Urgent && (await ai.SettingsAsync(house,ct))?.Enabled!=true) throw new ConflictException("AI is disabled for this household.");
        if (value.Status!=AIConstants.Ready || value.ExpiresAt<=clock.GetUtcNow().UtcDateTime) throw new ConflictException("Recommendation is not ready or has expired.");
        var context=await contexts.BuildAsync(house,value.SeasonId,ct);
        if (contexts.Fingerprint(context)!=value.ContextHash)
            throw new ConflictException("Schedule context changed. Request and review a new recommendation.");
        using var payload=JsonDocument.Parse(value.PayloadJson);
        if(payload.RootElement.TryGetProperty("status",out var feasibility) && feasibility.GetString() is "INFEASIBLE" or "NEEDS_CLARIFICATION")throw new ConflictException("The AI plan is not feasible; review the missing constraints before applying it.");
        if(value.Kind==AIConstants.Urgent) {
            if(!payload.RootElement.TryGetProperty("urgent_payload",out var urgentJson) || payload.RootElement.GetProperty("status").GetString()!="READY")throw new ConflictException("Urgent plan is not feasible or needs clarification.");
            var urgent=urgentJson.Deserialize<UrgentEventPayload>() ?? throw new DomainException("Invalid urgent plan.");
            var targets=urgent.Chores.Select(c=>c.AssignedUserId).Append(actor).Distinct().Where(id=>id!=actor).ToList();
            if(targets.Count==0)throw new ConflictException("Use a household participant to review the urgent plan.");
            var details=$"{(urgent.GuestCount.HasValue?$"Party for {urgent.GuestCount} guests. ":"")}{(urgent.ReadyByUtc.HasValue?$"Ready by {ScheduleTime.Local(urgent.ReadyByUtc.Value):yyyy-MM-dd HH:mm} (Vietnam time). ":"")}Review your assigned tasks and confirm participation.";
            var linked=await proposals.CreateProposalAsync(house,new CreateProposalRequest{Type=ProposalType.URGENT_EVENT,Title=urgent.Title ?? "AI Urgent Campaign Proposal",Description=details,PayloadJson=urgentJson.GetRawText(),TargetUserIds=targets,ExpiresAt=urgent.ReadyByUtc ?? clock.GetUtcNow().UtcDateTime.AddMinutes(5)},actor,ct);
            value.ProposalId=linked.Id;value.Status=AIConstants.Accepted;return View(value);
        }
        if (value.Kind==AIConstants.Swap) {
            if (!payload.RootElement.TryGetProperty("swap_payload",out var swap)) throw new ConflictException("No feasible swap was found.");
            var swapData=swap.Deserialize<ChoreSwapPayload>() ?? throw new DomainException("Invalid swap candidate.");
            var target=await uow.ChoreOccurrences.GetByIdAsync(swapData.TargetOccurrenceId,ct) ?? throw new NotFoundException("Swap target missing.");
            var linked=await proposals.CreateProposalAsync(house,new CreateProposalRequest{Type=ProposalType.CHORE_SWAP,Title="AI Chore Swap Proposal",Description="Both members must approve before responsibility changes.",PayloadJson=swap.GetRawText(),TargetUserIds=[target.AssignedUserId!.Value],ExpiresAt=value.ExpiresAt},actor,ct);
            value.ProposalId=linked.Id;value.Status=AIConstants.Accepted;return View(value);
        }
        if (value.Kind==AIConstants.Replan) {
            var old=context.GetProperty("tasks").EnumerateArray().ToDictionary(t=>t.GetProperty("id").GetGuid());
            var change=new ScheduleChangePayload{SeasonId=value.SeasonId,ContextHash=value.ContextHash,AvailabilityChanges=JsonSerializer.Deserialize<List<ScheduleAvailabilityChange>>(value.AvailabilityChangesJson) ?? []};
            var returned=payload.RootElement.GetProperty("tasks").EnumerateArray().ToList();
            if(returned.Count!=old.Count || returned.Select(t=>t.GetProperty("id").GetGuid()).Distinct().Count()!=old.Count)throw new DomainException("Replan must preserve the frozen occurrence universe.");
            foreach (var task in payload.RootElement.GetProperty("tasks").EnumerateArray()) {
                var taskId=task.GetProperty("id").GetGuid();
                if (!old.TryGetValue(taskId,out var previous)) throw new DomainException("Unknown replan occurrence.");
                if(task.GetProperty("minutes").GetInt32()!=previous.GetProperty("minutes").GetInt32() || task.GetProperty("karma").GetInt32()!=previous.GetProperty("karma").GetInt32() || task.GetProperty("due_at").GetDateTime().ToUniversalTime()!=previous.GetProperty("due_at").GetDateTime().ToUniversalTime())throw new DomainException("Replan may not change effort, Karma, or deadlines.");
                if (task.GetProperty("assigned_to").ValueKind==JsonValueKind.Null) continue;
                Guid? oldAssignee=previous.GetProperty("assigned_to").ValueKind==JsonValueKind.Null?null:previous.GetProperty("assigned_to").GetGuid();
                DateTime? oldStart=previous.GetProperty("start_at").ValueKind==JsonValueKind.Null?null:previous.GetProperty("start_at").GetDateTime().ToUniversalTime();
                DateTime? newStart=task.GetProperty("start_at").ValueKind==JsonValueKind.Null?null:task.GetProperty("start_at").GetDateTime().ToUniversalTime();
                if (task.GetProperty("assigned_to").GetGuid()!=oldAssignee || newStart!=oldStart) {
                    if (!newStart.HasValue) throw new DomainException("Replan assignment needs a planned start.");
                    change.Changes.Add(new ScheduleAssignment{OccurrenceId=taskId,AssignedUserId=task.GetProperty("assigned_to").GetGuid(),PlannedStartAt=newStart.Value,PreviousUserId=oldAssignee ?? Guid.Empty,PreviousStartAt=oldStart,Name=previous.GetProperty("name").GetString() ?? ""});
                }
            }
            var required=await scheduleChanges.ValidateAsync(house,change,ct);
            var linked=await proposals.CreateProposalAsync(house,new CreateProposalRequest{Type=ProposalType.SCHEDULE_REPLAN,Title="AI Schedule Change Proposal",Description="The owner and all affected members must approve.",PayloadJson=JsonSerializer.Serialize(change),TargetUserIds=required.Where(id=>id!=actor).ToList(),ExpiresAt=value.ExpiresAt},actor,ct);
            value.ProposalId=linked.Id;value.Status=linked.Status==ProposalStatus.APPROVED?AIConstants.Applied:AIConstants.Accepted;return View(value);
        }
        if (context.GetProperty("status").GetString()!=AIConstants.Draft) throw new ConflictException("Draft changed status.");
        var changes=payload.RootElement.GetProperty("tasks").EnumerateArray().ToList();
        var occurrences=(await uow.ChoreOccurrences.GetBySeasonIdAsync(value.SeasonId,ct)).Where(o=>o.Chore.Type==ChoreType.NORMAL).ToDictionary(o=>o.Id);
        if (changes.Count!=occurrences.Count || changes.Select(t=>t.GetProperty("id").GetGuid()).Distinct().Count()!=changes.Count || changes.Any(t=>!occurrences.ContainsKey(t.GetProperty("id").GetGuid())))
            throw new DomainException("AI returned an invalid set of occurrences.");
        foreach (var change in changes)
        {
            var occurrence=occurrences[change.GetProperty("id").GetGuid()];
            if (change.GetProperty("minutes").GetInt32()!=AllocationEligibilityService.Minutes(occurrence) || change.GetProperty("karma").GetInt32()!=occurrence.SnapshotKarma || change.GetProperty("due_at").GetDateTime().ToUniversalTime()!=occurrence.DueDate)
                throw new DomainException("AI may not alter deadline, effort, or Karma snapshots.");
            occurrence.AssignedUserId=change.GetProperty("assigned_to").ValueKind==JsonValueKind.Null?null:change.GetProperty("assigned_to").GetGuid();
            occurrence.PlannedStartAt=change.GetProperty("start_at").ValueKind==JsonValueKind.Null?null:change.GetProperty("start_at").GetDateTime().ToUniversalTime();
        }
        await ValidateScheduleAsync(context,occurrences.Values.ToList(),ct);
        // Core revalidates hard constraints; policy quality remains auditable in the stored preview.
        foreach (var occurrence in occurrences.Values) uow.ChoreOccurrences.Update(occurrence);
        var season=await uow.Seasons.GetByIdAsync(value.SeasonId,ct) ?? throw new NotFoundException("Season not found.");
        season.ScheduleRevision++;uow.Seasons.Update(season);value.Status=AIConstants.Applied;
        return View(value);
    },ct);

    public static Task ValidateScheduleAsync(JsonElement context, List<ChoreOccurrence> occurrences, CancellationToken ct, IReadOnlySet<Guid>? scope=null)
    {
        foreach (var member in context.GetProperty("members").EnumerateArray())
        {
            ct.ThrowIfCancellationRequested();
            var id=member.GetProperty("id").GetGuid();
            var assigned=occurrences.Where(o=>o.AssignedUserId==id).ToList();
            if (assigned.GroupBy(o=>{var d=ScheduleTime.Local(o.DueDate);return (System.Globalization.ISOWeek.GetYear(d),System.Globalization.ISOWeek.GetWeekOfYear(d));}).Any(g=>(scope==null || g.Any(o=>scope.Contains(o.Id))) && g.Count()>member.GetProperty("max_chores_per_week").GetInt32())) throw new ConflictException("Weekly capacity exceeded.");
            foreach (var day in assigned.GroupBy(o=>ScheduleTime.Local(o.DueDate).Date))
            {
                if(scope!=null && !day.Any(o=>scope.Contains(o.Id)))continue;
                if (day.Sum(AllocationEligibilityService.Minutes)>member.GetProperty("max_minutes_per_day").GetInt32()) throw new ConflictException("Daily capacity exceeded.");
                List<(int Start,int End)> slots=[];
                if (member.GetProperty("date_exceptions").TryGetProperty(day.Key.ToString("yyyy-MM-dd"),out var exception))
                    slots=exception.EnumerateArray().Select(s=>(s.GetProperty("start").GetInt32(),s.GetProperty("end").GetInt32())).ToList();
                else {
                    var av=member.GetProperty("availability").EnumerateArray().FirstOrDefault(a=>a.GetProperty("day").GetInt32()==(int)day.Key.DayOfWeek);
                    if (av.ValueKind!=JsonValueKind.Undefined && av.GetProperty("available").GetBoolean()) {
                        slots=av.GetProperty("slots").EnumerateArray().Select(s=>(s.GetProperty("start").GetInt32(),s.GetProperty("end").GetInt32())).ToList();
                        if (slots.Count==0) slots.Add((0,1440));
                    }
                }
                var ordered=day.OrderBy(o=>o.PlannedStartAt).ToList();
                foreach (var task in ordered) {
                    if(task.Status is ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED)continue;
                    if(scope!=null && !scope.Contains(task.Id))continue;
                    if (!task.PlannedStartAt.HasValue) throw new ConflictException("Assigned task needs a start time.");
                    var start=task.PlannedStartAt.Value;var local=ScheduleTime.Local(start);var minutes=AllocationEligibilityService.Minutes(task);
                    var collision=assigned.Any(other=>other.Id!=task.Id && other.Status is not (ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED) && other.PlannedStartAt.HasValue && other.PlannedStartAt.Value<start.AddMinutes(minutes) && other.PlannedStartAt.Value.AddMinutes(AllocationEligibilityService.Minutes(other))>start);
                    if (local.Date!=day.Key || !slots.Any(s=>ScheduleTime.Utc(DateOnly.FromDateTime(local),s.Start)<=start && start.AddMinutes(minutes)<=ScheduleTime.Utc(DateOnly.FromDateTime(local),s.End)) || start.AddMinutes(minutes)>task.DueDate || collision)
                        throw new ConflictException("AI schedule conflicts with availability, deadline, or another task.");
                }
            }
        }
        var active=context.GetProperty("members").EnumerateArray().Select(m=>m.GetProperty("id").GetGuid()).ToHashSet();
        if (occurrences.Any(o=>(scope==null || scope.Contains(o.Id)) && o.AssignedUserId.HasValue && !active.Contains(o.AssignedUserId.Value))) throw new ConflictException("Inactive AI assignee.");
        return Task.CompletedTask;
    }

    public async Task<JsonElement> InterpretAsync(Guid house, Guid actor, AITextRequest request, bool chat, CancellationToken ct)
    {
        var validation=await textValidator.ValidateAsync(request,ct);
        if(!validation.IsValid)throw new ChoreWars.Domain.Exceptions.ValidationException(validation.Errors.GroupBy(e=>e.PropertyName).ToDictionary(g=>g.Key,g=>g.Select(e=>e.ErrorMessage).ToArray()));
        await AuthorizeAsync(house,actor,false,ct);
        if (chat && (await ai.SettingsAsync(house,ct))?.Enabled!=true) throw new ConflictException("AI is disabled for this household.");
        var consent=await ai.ConsentAsync(house,actor,ct);
        if (chat && consent?.ChatAnalysisEnabled!=true) throw new ForbiddenException("Sender consent is required to analyze chat.");
        var version=consent?.Version;
        var names=(await uow.HouseMembers.GetByHouseIdAsync(house,ct)).Where(m=>m.Status==HouseMemberStatus.ACTIVE).ToDictionary(m=>m.UserId.ToString(),m=>m.User?.DisplayName ?? "");
        var chores=(await uow.Chores.GetByHouseIdAsync(house,ct)).ToDictionary(c=>c.Id.ToString(),c=>c.Name);
        var occurrences=(await uow.ChoreOccurrences.GetUnresolvedByHouseIdAsync(house,ct)).Where(o=>o.AssignedUserId==actor).ToDictionary(o=>o.Id.ToString(),o=>o.Chore.Name);
        var catalog = new Dictionary<string,object>();
        var allowedProducts = new Dictionary<Guid,SupplyProduct>();
        if (uow.Supplies is { } supplies)
            foreach (var supplier in await supplies.HouseSuppliersAsync(house,ct))
                foreach (var product in (await supplies.ProductsAsync(supplier.Id,ct)).Where(p=>p.Active)) {
                    allowedProducts[product.Id]=product;
                    catalog[product.Id.ToString()]=new{supplier_id=product.SupplierId,name=product.Name,unit=product.Unit,price=(long)product.Price,available_quantity=product.AvailableQuantity};
                }
        var result=await client.PostAsync(house,actor,"/v1/interpret",new{house_id=house,actor_id=actor,text=request.Text,now=clock.GetUtcNow(),member_names=names,chore_names=chores,occurrence_names=occurrences,supply_catalog=catalog,consent_version=chat?$"{version}":"ON_DEMAND",purpose=chat?"chat":"interpret"},ct);
        ChoreWars.Application.Services.Supplies.SupplyAIContract.Validate(result,names.Keys.ToHashSet(),allowedProducts);
        return await mutations.RunAsync(house,async()=> {
            await AuthorizeAsync(house,actor,false,ct);
            if (chat && (await ai.SettingsAsync(house,ct))?.Enabled!=true) throw new ConflictException("AI was disabled while processing.");
            if (chat) {
                var current=await ai.ConsentAsync(house,actor,ct);
                if (current?.ChatAnalysisEnabled!=true || current.Version!=version) throw new ConflictException("Consent changed while AI was processing.");
            }
            return result;
        },ct);
    }

    public async Task<JsonElement> ChatInsightsAsync(Guid house, Guid actor, CancellationToken ct) {
        await AuthorizeAsync(house,actor,false,ct);
        if ((await ai.ConsentAsync(house,actor,ct))?.ChatAnalysisEnabled!=true) throw new ForbiddenException("Chat insight consent is required.");
        var items=await ai.ChatInsightsAsync(house,actor,ct);
        return JsonSerializer.SerializeToElement(new{items=items.Select(i=>new{id=i.Id,message_id=i.MessageId,status=i.Status,created_at=i.CreatedAt,result=JsonSerializer.Deserialize<JsonElement>(i.ResultJson),consent_version=i.ConsentVersion})});
    }

    public async Task<JsonElement> OwnRiskAsync(Guid house, Guid actor, CancellationToken ct) {
        await AuthorizeAsync(house,actor,false,ct);
        if((await ai.SettingsAsync(house,ct))?.Enabled!=true)throw new ConflictException("AI is disabled for this household.");
        var episodes=await ai.OwnOpenEpisodesAsync(house,actor,clock.GetUtcNow().UtcDateTime,ct);
        if(episodes.Count==0)return JsonSerializer.SerializeToElement(new{items=Array.Empty<object>(),status="NO_OPEN_OBSERVED_RESPONSIBILITY",push_notifications=false});
        var result=await client.PostAsync(house,actor,"/v1/predictions/evaluate-batch",new{house_id=house,episode_ids=episodes},ct);
        return await mutations.RunAsync(house,async()=>{await AuthorizeAsync(house,actor,false,ct);return result;},ct);
    }

    public async Task<JsonElement> EvaluateAsync(Guid house, Guid actor, Guid season, CancellationToken ct) {
        var context=await mutations.RunAsync(house,async()=> {await AuthorizeAsync(house,actor,true,ct);return await contexts.BuildAsync(house,season,ct);},ct);
        var result=await client.PostAsync(house,actor,"/internal/evaluations",new{context,history_enabled=true,mode="SERVING_DEADLINE"},ct);
        return await mutations.RunAsync(house,async()=> {await AuthorizeAsync(house,actor,true,ct);return result;},ct);
    }

    public async Task<JsonElement> BountySuggestionsAsync(Guid house, Guid actor, CancellationToken ct) {
        await AuthorizeAsync(house,actor,false,ct);
        if((await ai.SettingsAsync(house,ct))?.Enabled!=true)throw new ConflictException("AI is disabled for this household.");
        var season=await uow.Seasons.GetActiveSeasonByHouseIdAsync(house,ct) ?? throw new ConflictException("An active season is required.");
        var data=await mutations.RunAsync(house,async()=> {
            await AuthorizeAsync(house,actor,false,ct);
            var context=await contexts.BuildAsync(house,season.Id,ct);
            var occurrences=(await uow.ChoreOccurrences.GetBySeasonIdAsync(season.Id,ct)).ToDictionary(o=>o.Id);
            var offers=new List<object>();
            foreach(var item in occurrences.Values) {
                var bounty=await uow.ChoreBounties.GetByOccurrenceIdAsync(item.Id,ct);
                if(bounty?.Status==BountyStatus.OPEN && bounty.ExpiresAt>clock.GetUtcNow().UtcDateTime && bounty.PostedByUserId!=actor)
                    offers.Add(new{id=bounty.Id,occurrence_id=item.Id,amount=bounty.Amount,expires_at=bounty.ExpiresAt});
            }
            return new{context,offers};
        },ct);
        var result=await client.PostAsync(house,actor,"/v1/bounties/suggestions",data,ct);
        return await mutations.RunAsync(house,async()=> {await AuthorizeAsync(house,actor,false,ct);return result;},ct);
    }

    public Task<JsonElement> SetAvailabilityExceptionAsync(Guid house, Guid actor, AIAvailabilityExceptionRequest request, CancellationToken ct) => mutations.RunAsync(house,async()=> {
        await AuthorizeAsync(house,actor,false,ct);await access.EnsureWritableAsync(house,ct);
        var season=await uow.Seasons.GetByIdAsync(request.SeasonId,ct) ?? throw new NotFoundException("Season not found.");
        if(season.HouseId!=house)throw new NotFoundException("Season not found.");
        if(season.Status!=SeasonStatus.DRAFT)throw new ConflictException("Date exceptions can be edited during draft; an active schedule requires a consented replan.");
        if(request.LocalDate<DateOnly.FromDateTime(ScheduleTime.Local(season.StartDate)) || request.LocalDate>DateOnly.FromDateTime(ScheduleTime.Local(season.EndDate)))throw new DomainException("Exception date must be in the season.");
        var windows=request.Slots.OrderBy(s=>s.Length==2?s[0]:-1).ToList();
        for(int i=0;i<windows.Count;i++)
            if(windows[i].Length!=2 || windows[i][0]<0 || windows[i][1]>1440 || windows[i][0]>=windows[i][1] || i>0 && windows[i-1][1]>windows[i][0])throw new DomainException("Availability windows must be valid and must not overlap.");
        var old=(await ai.AvailabilityExceptionsAsync(season.Id,ct)).SingleOrDefault(x=>x.UserId==actor && x.LocalDate==request.LocalDate);
        if(old==null) {old=new MemberAvailabilityException{Id=Guid.NewGuid(),SeasonId=season.Id,UserId=actor,LocalDate=request.LocalDate};ai.AddAvailabilityException(old);}
        var serialized=JsonSerializer.Serialize(windows.Select(w=>new{start=w[0],end=w[1]}));
        if(old.SlotsJson!=serialized) {old.SlotsJson=serialized;season.ScheduleRevision++;uow.Seasons.Update(season);}
        return JsonSerializer.SerializeToElement(new{season_id=season.Id,local_date=request.LocalDate,slots=JsonSerializer.Deserialize<JsonElement>(old.SlotsJson),revision=season.ScheduleRevision});
    },ct);

    public async Task<JsonElement> ConfirmAvailabilityAsync(Guid house, Guid actor, AIAvailabilityChangeRequest request, CancellationToken ct)
    {
        var validation=await availabilityValidator.ValidateAsync(request,ct);
        if(!validation.IsValid)throw new ChoreWars.Domain.Exceptions.ValidationException(validation.Errors.GroupBy(e=>e.PropertyName).ToDictionary(g=>g.Key,g=>g.Select(e=>e.ErrorMessage).ToArray()));
        if(request.ClientRequestId==Guid.Empty || request.SeasonId==Guid.Empty || request.StartMinute<0 || request.EndMinute>1440 || request.StartMinute>=request.EndMinute)
            throw new DomainException("A request ID, season and valid local time interval are required.");
        var commandHash=Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(request))));
        AIGenerateRequest? generation=null;
        var immediate=await mutations.RunAsync(house,async()=> {
            await AuthorizeAsync(house,actor,false,ct);await access.EnsureWritableAsync(house,ct);
            var old=await ai.FindRequestAsync(house,actor,request.ClientRequestId,ct);
            if(old!=null) {if(old.InputHash!=commandHash)throw new ConflictException("Request ID already used with different input.");return (JsonElement?)View(old);}
            if(request.InsightId.HasValue) {
                var insight=(await ai.ChatInsightsAsync(house,actor,ct)).SingleOrDefault(i=>i.Id==request.InsightId.Value);
                var consent=await ai.ConsentAsync(house,actor,ct);
                if(insight?.Status!="READY" || consent?.ChatAnalysisEnabled!=true || insight.ConsentVersion!=consent.Version || (await ai.SettingsAsync(house,ct))?.Enabled!=true)
                    throw new ConflictException("The private chat suggestion is no longer available; review your availability directly.");
            }
            var context=await contexts.BuildAsync(house,request.SeasonId,ct);
            var member=context.GetProperty("members").EnumerateArray().Single(m=>m.GetProperty("id").GetGuid()==actor);
            var slots=new List<(int Start,int End)>();
            if(member.GetProperty("date_exceptions").TryGetProperty(request.LocalDate.ToString("yyyy-MM-dd"),out var dateSlots))
                slots.AddRange(dateSlots.EnumerateArray().Select(s=>(s.GetProperty("start").GetInt32(),s.GetProperty("end").GetInt32())));
            else foreach(var day in member.GetProperty("availability").EnumerateArray().Where(d=>d.GetProperty("day").GetInt32()==(int)request.LocalDate.DayOfWeek && d.GetProperty("available").GetBoolean()))
                slots.AddRange(day.GetProperty("slots").EnumerateArray().Select(s=>(s.GetProperty("start").GetInt32(),s.GetProperty("end").GetInt32())));
            if(request.Busy) slots=slots.SelectMany(s=>new[]{(Start:s.Start,End:Math.Min(s.End,request.StartMinute)),(Start:Math.Max(s.Start,request.EndMinute),End:s.End)}).Where(s=>s.Start<s.End).ToList();
            else slots.Add((request.StartMinute,request.EndMinute));
            var merged=new List<(int Start,int End)>();
            foreach(var slot in slots.OrderBy(s=>s.Start)) {
                if(merged.Count>0 && slot.Start<=merged[^1].End)merged[^1]=(merged[^1].Start,Math.Max(merged[^1].End,slot.End));
                else merged.Add(slot);
            }
            var change=new ScheduleAvailabilityChange{UserId=actor,LocalDate=request.LocalDate,Slots=merged.Select(s=>new AvailabilitySlotRequest{StartMinute=s.Start,EndMinute=s.End}).ToList()};
            await scheduleChanges.CandidateContextAsync(house,request.SeasonId,context,[change],ct);
            if(context.GetProperty("status").GetString()=="DRAFT") {
                var season=await uow.Seasons.GetByIdAsync(request.SeasonId,ct) ?? throw new NotFoundException("Season not found.");
                var row=(await ai.AvailabilityExceptionsAsync(season.Id,ct)).SingleOrDefault(x=>x.UserId==actor && x.LocalDate==request.LocalDate);
                if(row==null) {row=new MemberAvailabilityException{Id=Guid.NewGuid(),SeasonId=season.Id,UserId=actor,LocalDate=request.LocalDate};ai.AddAvailabilityException(row);}
                var serialized=JsonSerializer.Serialize(merged.Select(s=>new{start=s.Start,end=s.End}));
                if(row.SlotsJson!=serialized) {row.SlotsJson=serialized;season.ScheduleRevision++;uow.Seasons.Update(season);}
                return (JsonElement?)JsonSerializer.SerializeToElement(new{status="APPLIED_DRAFT",revision=season.ScheduleRevision,availability_changes=new[]{change}});
            }
            generation=new AIGenerateRequest{ClientRequestId=request.ClientRequestId,SeasonId=request.SeasonId,Kind=AIConstants.Replan,AvailabilityChanges=[change],ExpectedContextHash=contexts.Fingerprint(context)};
            return null;
        },ct);
        return immediate ?? await GenerateCoreAsync(house,actor,generation!,ct,commandHash);
    }

    private static JsonElement View(AIRecommendation value) => JsonSerializer.SerializeToElement(new{id=value.Id,status=value.Status,kind=value.Kind,expires_at=value.ExpiresAt,result=JsonSerializer.Deserialize<JsonElement>(value.PayloadJson),availability_changes=JsonSerializer.Deserialize<JsonElement>(value.AvailabilityChangesJson),proposal_id=value.ProposalId});
}
