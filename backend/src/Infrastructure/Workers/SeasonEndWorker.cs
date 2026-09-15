using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Infrastructure.Workers;

public class SeasonEndWorker : BackgroundService
{
    private readonly ILogger<SeasonEndWorker> _logger;
    private readonly IServiceScopeFactory _scopeFactory;

    public SeasonEndWorker(ILogger<SeasonEndWorker> logger, IServiceScopeFactory scopeFactory)
    {
        _logger = logger;
        _scopeFactory = scopeFactory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("SeasonEndWorker is starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                _logger.LogInformation("SeasonEndWorker running at: {time}", DateTimeOffset.Now);
                
                using (var scope = _scopeFactory.CreateScope())
                {
                    var service = scope.ServiceProvider.GetRequiredService<ISeasonEndService>();
                    await service.ProcessEndedSeasonsAsync(stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred executing SeasonEndWorker.");
            }

            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
