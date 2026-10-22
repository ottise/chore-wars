using System.Text.Json;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.AI;

public sealed class AIChatInsightWorker(IServiceScopeFactory scopes, IOptions<AIOptions> options, ILogger<AIChatInsightWorker> logger) : BackgroundService
{
    private const int MaxAttempts=3;
    private static readonly TimeSpan Lease=TimeSpan.FromMinutes(2);
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (!options.Value.Enabled) return;
        while(!ct.IsCancellationRequested) {
            try { await ProcessOneAsync(ct); }
            catch(OperationCanceledException) when(ct.IsCancellationRequested) { break; }
            catch(Exception error) { logger.LogWarning("AI chat queue failed ({ErrorType}); retrying without logging message content.",error.GetType().Name); }
            try { await Task.Delay(TimeSpan.FromSeconds(5),ct); } catch(OperationCanceledException) when(ct.IsCancellationRequested) { break; }
        }
    }

    public async Task ProcessOneAsync(CancellationToken ct)
    {
        await using var scope=scopes.CreateAsyncScope();
        var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var mutations=scope.ServiceProvider.GetRequiredService<IHouseMutationCoordinator>();
        var now=scope.ServiceProvider.GetRequiredService<TimeProvider>().GetUtcNow().UtcDateTime;
        var expiredLease=now-Lease;
        var candidate=await db.AIChatInsights.AsNoTracking().Where(j=>j.Attempts<MaxAttempts && (j.Status=="WAITING" || j.Status=="PROCESSING" && j.ProcessedAt<expiredLease)).OrderBy(j=>j.CreatedAt).FirstOrDefaultAsync(ct);
        if(candidate==null)return;
        string? text=null;
        await mutations.RunAsync(candidate.HouseId,async()=> {
            var job=await db.AIChatInsights.SingleOrDefaultAsync(j=>j.Id==candidate.Id,ct);
            if(job==null || job.Status is not ("WAITING" or "PROCESSING") || job.Status=="PROCESSING" && job.ProcessedAt>=expiredLease)return;
            var consent=await db.MemberAiConsents.SingleOrDefaultAsync(c=>c.HouseId==job.HouseId && c.UserId==job.UserId,ct);
            var settings=await db.HouseAiSettings.SingleOrDefaultAsync(s=>s.HouseId==job.HouseId,ct);
            var member=await db.HouseMembers.SingleOrDefaultAsync(m=>m.HouseId==job.HouseId && m.UserId==job.UserId,ct);
            if(consent?.ChatAnalysisEnabled!=true || consent.Version!=job.ConsentVersion || settings?.Enabled!=true || !settings.ChatAutoInsightsEnabled || member?.Status!=HouseMemberStatus.ACTIVE || job.CreatedAt<now.AddDays(-1)) {
                db.AIChatInsights.Remove(job);return;
            }
            text=await db.ChatMessages.Where(m=>m.Id==job.MessageId && m.SenderId==job.UserId).Select(m=>m.Content).SingleOrDefaultAsync(ct);
            job.Status="PROCESSING";job.ProcessedAt=now;job.Attempts++;
        },ct);
        if(string.IsNullOrWhiteSpace(text))return;
        try {
            var service=scope.ServiceProvider.GetRequiredService<IAIHousekeeperService>();
            var result=await service.InterpretAsync(candidate.HouseId,candidate.UserId,new AITextRequest{Text=text},true,ct);
            await mutations.RunAsync(candidate.HouseId,async()=> {
                var job=await db.AIChatInsights.SingleOrDefaultAsync(j=>j.Id==candidate.Id,ct);
                var consent=await db.MemberAiConsents.SingleOrDefaultAsync(c=>c.HouseId==candidate.HouseId && c.UserId==candidate.UserId,ct);
                if(job==null)return;
                if(consent?.ChatAnalysisEnabled!=true || consent.Version!=job.ConsentVersion) { db.AIChatInsights.Remove(job);return; }
                job.ResultJson=result.GetRawText();job.Status="READY";job.ProcessedAt=now;
            },ct);
        } catch(OperationCanceledException) when(ct.IsCancellationRequested) { throw; }
        catch(Exception error) {
            logger.LogWarning("Chat insight inference failed ({ErrorType}).",error.GetType().Name);
            await mutations.RunAsync(candidate.HouseId,async()=> {
                var job=await db.AIChatInsights.SingleOrDefaultAsync(j=>j.Id==candidate.Id,ct);
                if(job!=null) {job.Status=job.Attempts>=MaxAttempts?"FAILED":"WAITING";job.ResultJson="{}";}
            },ct);
        }
    }
}
