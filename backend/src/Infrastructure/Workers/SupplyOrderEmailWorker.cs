using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
namespace ChoreWars.Infrastructure.Workers;
public sealed class SupplyOrderEmailWorker(IServiceScopeFactory scopes, TimeProvider clock, ILogger<SupplyOrderEmailWorker> log) : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(3);
    private static readonly TimeSpan SendTimeout = TimeSpan.FromSeconds(30);
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                using var scope = scopes.CreateScope();
                var sender = scope.ServiceProvider.GetRequiredService<ISupplyOrderEmailSender>();
                if (sender.IsConfigured)
                {
                    var repository = scope.ServiceProvider.GetRequiredService<ISupplyRepository>();
                    var dispatch = await repository.ClaimEmailAsync(clock.GetUtcNow().UtcDateTime, ct);
                    if (dispatch != null)
                    {
                        var state = OrderEmailState.Sent;
                        string? code = null;
                        try
                        {
                            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                            timeout.CancelAfter(SendTimeout);
                            await sender.SendAsync(dispatch.Id, dispatch.Recipient, dispatch.Subject, dispatch.Body, timeout.Token);
                        }
                        catch (Exception error)
                        {
                            state = OrderEmailState.Unknown;
                            code = "SEND_RESULT_UNCERTAIN";
                            log.LogWarning("Order email dispatch {DispatchId} has an uncertain result ({ErrorType}); no automatic resend.", dispatch.Id, error.GetType().Name);
                        }
                        // A timeout/disconnect may happen after SMTP accepted the message. Only a person may request another attempt.
                        await repository.CompleteEmailAsync(dispatch.Id, dispatch.LeaseId!.Value, state, code, clock.GetUtcNow().UtcDateTime, CancellationToken.None);
                    }
                }
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { break; }
            catch (Exception error) { log.LogWarning("Order email worker could not complete a poll ({ErrorType}).", error.GetType().Name); }
            try { await Task.Delay(PollInterval, ct); } catch (OperationCanceledException) when (ct.IsCancellationRequested) { break; }
        }
    }
}
