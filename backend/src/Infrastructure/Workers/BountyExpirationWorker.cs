using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Infrastructure.Workers;

public class BountyExpirationWorker : BackgroundService
{
    private readonly ILogger<BountyExpirationWorker> _logger;
    private readonly IServiceScopeFactory _scopeFactory;

    public BountyExpirationWorker(ILogger<BountyExpirationWorker> logger, IServiceScopeFactory scopeFactory)
    {
        _logger = logger;
        _scopeFactory = scopeFactory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("BountyExpirationWorker is starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                _logger.LogInformation("BountyExpirationWorker running at: {time}", DateTimeOffset.Now);
                
                using (var scope = _scopeFactory.CreateScope())
                {
                    var service = scope.ServiceProvider.GetRequiredService<IBountyExpirationService>();
                    await service.ProcessExpiredBountiesAsync(stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred executing BountyExpirationWorker.");
            }

            await Task.Delay(TimeSpan.FromMinutes(15), stoppingToken);
        }
    }
}
