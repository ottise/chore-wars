using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
namespace ChoreWars.Infrastructure.Repositories;

// Runs only after the new application is deployed. Old binaries never see the new commitment status.
public sealed class LegacyBountyRecovery(IServiceScopeFactory scopes, TimeProvider clock, ILogger<LegacyBountyRecovery> logger) : IHostedService {
    public async Task StartAsync(CancellationToken ct) {
        try {
            await using var read=scopes.CreateAsyncScope();
            var db=read.ServiceProvider.GetRequiredService<AppDbContext>();
            var houses=await db.ChoreBounties.AsNoTracking().Where(b=>(b.Status==BountyStatus.OPEN||b.Status==BountyStatus.CLAIMED)&&!b.ChoreOccurrence.Chore.House.IsArchived).Select(b=>b.ChoreOccurrence.Chore.HouseId).Distinct().ToListAsync(ct);
            foreach(var house in houses) {
                await using var scope=scopes.CreateAsyncScope();
                var store=scope.ServiceProvider.GetRequiredService<AppDbContext>();
                var mutations=scope.ServiceProvider.GetRequiredService<IHouseMutationCoordinator>();
                await mutations.RunAsync(house,async ()=>{
                    var bounties=await store.ChoreBounties.Include(b=>b.ChoreOccurrence).ThenInclude(o=>o.Chore).Where(b=>b.ChoreOccurrence.Chore.HouseId==house&&(b.Status==BountyStatus.OPEN||b.Status==BountyStatus.CLAIMED)).ToListAsync(ct);
                    var now=clock.GetUtcNow().UtcDateTime;
                    foreach(var bounty in bounties) {
                        var occurrence=bounty.ChoreOccurrence;
                        if(bounty.Status==BountyStatus.OPEN && occurrence.Status==ChoreOccurrenceStatus.ASSIGNED && occurrence.DueDate>now) bounty.ExpiresAt=occurrence.DueDate;
                        if(bounty.Status!=BountyStatus.CLAIMED || occurrence.AssignedUserId is not Guid recipient || recipient==bounty.PostedByUserId || occurrence.Status is ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED) continue;
                        bounty.ClaimedByUserId??=recipient;
                        if(await store.PaymentObligations.AnyAsync(p=>p.OccurrenceId==occurrence.Id && p.Reason==PaymentObligationReason.BOUNTY_PAYMENT && p.Status!=PaymentObligationStatus.CANCELLED,ct))continue;
                        // A claimed, unfinished occurrence is the evidence of the commitment. Never synthesize completed or paid history.
                        store.PaymentObligations.Add(new PaymentObligation {Id=Guid.NewGuid(),HouseId=house,SeasonId=occurrence.SeasonId,OccurrenceId=occurrence.Id,DebtorUserId=bounty.PostedByUserId,CreditorUserId=recipient,Amount=bounty.Amount,Reason=PaymentObligationReason.BOUNTY_PAYMENT,Status=PaymentObligationStatus.AWAITING_COMPLETION,CreatedAt=now});
                    }
                    await store.SaveChangesAsync(ct);
                },ct);
            }
        } catch(OperationCanceledException) when(ct.IsCancellationRequested) { throw; }
        catch(Exception error) { logger.LogWarning(error,"Legacy bounty recovery did not finish; existing records were preserved. Retry by restarting after checking database readiness."); }
    }
    public Task StopAsync(CancellationToken ct)=>Task.CompletedTask;
}
