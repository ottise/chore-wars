using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
namespace ChoreWars.Infrastructure.Workers;
public sealed class MediaCleanupWorker(IServiceScopeFactory scopes, ILogger<MediaCleanupWorker> logger):BackgroundService {
    protected override async Task ExecuteAsync(CancellationToken ct) {
        while(!ct.IsCancellationRequested) {
            try {
                using var scope=scopes.CreateScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
                var storage=scope.ServiceProvider.GetRequiredService<IMediaStorage>();var mutations=scope.ServiceProvider.GetRequiredService<IHouseMutationCoordinator>();
                var cutoff=DateTime.UtcNow.AddHours(-24);
                var pending=await db.MediaAttachments.AsNoTracking().Where(m=>m.AttachedAt==null&&m.CreatedAt<cutoff).Take(100).ToListAsync(ct);
                foreach(var candidate in pending) {
                    var houseId=await db.ChatRooms.Where(r=>r.Id==candidate.RoomId).Select(r=>r.HouseId).SingleAsync(ct);
                    await mutations.RunAsync(houseId,async()=>{
                        var media=await db.MediaAttachments.SingleOrDefaultAsync(m=>m.Id==candidate.Id,ct);
                        if(media==null||media.AttachedAt!=null||media.CreatedAt>=cutoff)return;
                        await storage.DeleteAsync(media.StorageKey,ct);db.MediaAttachments.Remove(media);
                    },ct);
                }
            } catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}
            catch(Exception ex){logger.LogWarning(ex,"Media cleanup failed; will retry.");}
            try { await Task.Delay(TimeSpan.FromHours(1),ct); } catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}
        }
    }
}
