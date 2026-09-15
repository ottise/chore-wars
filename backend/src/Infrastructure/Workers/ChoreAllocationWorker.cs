using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Infrastructure.Workers;

public class ChoreAllocationWorker : BackgroundService
{
    private readonly ILogger<ChoreAllocationWorker> _logger;
    private readonly IServiceScopeFactory _scopeFactory;

    public ChoreAllocationWorker(ILogger<ChoreAllocationWorker> logger, IServiceScopeFactory scopeFactory)
    {
        _logger = logger;
        _scopeFactory = scopeFactory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("ChoreAllocationWorker is starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                _logger.LogInformation("ChoreAllocationWorker running at: {time}", DateTimeOffset.Now);
                
                using (var scope = _scopeFactory.CreateScope())
                {
                    var service = scope.ServiceProvider.GetRequiredService<IChoreAllocationService>();
                    await service.AllocateChoresAsync(stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred executing ChoreAllocationWorker.");
            }

            await Task.Delay(TimeSpan.FromHours(24), stoppingToken);
        }
    }
}
