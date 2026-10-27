using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
namespace ChoreWars.Infrastructure.Workers;
public sealed class SupplyReminderWorker(IServiceScopeFactory scopes,ILogger<SupplyReminderWorker> log,TimeProvider clock):BackgroundService
{
 protected override async Task ExecuteAsync(CancellationToken ct){
  while(!ct.IsCancellationRequested){
   try{await using var scope=scopes.CreateAsyncScope();var services=scope.ServiceProvider;var ids=await services.GetRequiredService<ISupplyRepository>().DueSchedulesAsync(clock.GetUtcNow().UtcDateTime,ct);
    foreach(var id in ids){await using var item=scopes.CreateAsyncScope();try{await item.ServiceProvider.GetRequiredService<ISupplyReminderService>().ProcessAsync(id,ct);}catch(OperationCanceledException)when(ct.IsCancellationRequested){throw;}catch(Exception ex){log.LogError(ex,"Supply reminder {Id} failed; it remains eligible for retry",id);}}
    foreach(var id in await services.GetRequiredService<ISupplyRepository>().ExpiredOrdersAsync(clock.GetUtcNow().UtcDateTime,ct)){
     await using var item=scopes.CreateAsyncScope();await item.ServiceProvider.GetRequiredService<ISupplyOrderService>().ExpireAsync(id,ct);
    }
   }catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}catch(Exception ex){log.LogError(ex,"Supply reminders could not be processed");}
   try{await Task.Delay(TimeSpan.FromMinutes(1),ct);}catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}
  }
 }
}
