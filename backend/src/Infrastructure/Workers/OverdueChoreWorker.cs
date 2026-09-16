using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Infrastructure.Workers;

public class OverdueChoreWorker : BackgroundService
{
    private readonly ILogger<OverdueChoreWorker> _logger;
    private readonly IServiceScopeFactory _scopeFactory;

    public OverdueChoreWorker(ILogger<OverdueChoreWorker> logger, IServiceScopeFactory scopeFactory)
    {
        _logger = logger;
        _scopeFactory = scopeFactory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("OverdueChoreWorker is starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                _logger.LogInformation("OverdueChoreWorker running at: {time}", DateTimeOffset.Now);
                
                using (var scope = _scopeFactory.CreateScope())
                {
                    var service = scope.ServiceProvider.GetRequiredService<IOverduePenaltyService>();
                    await service.ProcessOverduePenaltiesAsync(stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred executing OverdueChoreWorker.");
            }

            await Task.Delay(TimeSpan.FromMinutes(15), stoppingToken);
        }
    }
}
