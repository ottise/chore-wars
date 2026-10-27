using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using ChoreWars.Infrastructure.Payments;
namespace ChoreWars.Infrastructure.Workers;
public sealed class SupplierPaymentReconciliationWorker(IServiceScopeFactory scopes,ILogger<SupplierPaymentReconciliationWorker> log,IOptions<PayOsOptions> options,TimeProvider clock):BackgroundService
{
 protected override async Task ExecuteAsync(CancellationToken ct){while(!ct.IsCancellationRequested){
  try{if(options.Value.Enabled){await using var scope=scopes.CreateAsyncScope();var pending=await scope.ServiceProvider.GetRequiredService<ISupplyRepository>().PendingPaymentsAsync(clock.GetUtcNow().UtcDateTime,ct);
   foreach(var p in pending){await using var item=scopes.CreateAsyncScope();try{await item.ServiceProvider.GetRequiredService<ISupplierPaymentService>().ReconcileAsync(p.Id,ct);}catch(OperationCanceledException)when(ct.IsCancellationRequested){throw;}catch(Exception ex){log.LogWarning(ex,"Supplier payment {Id} needs reconciliation",p.Id);}}
  }}catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}catch(Exception ex){log.LogError(ex,"Supplier reconciliation failed");}
  try{await Task.Delay(TimeSpan.FromMinutes(2),ct);}catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}
 }}
}
