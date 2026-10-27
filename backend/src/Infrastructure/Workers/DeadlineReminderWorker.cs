using ChoreWars.Application.Interfaces.Services;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Events;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Infrastructure.Workers;

public class DeadlineReminderWorker : BackgroundService
{
    private readonly ILogger<DeadlineReminderWorker> _logger;
    private readonly IServiceScopeFactory _scopeFactory;

    public DeadlineReminderWorker(ILogger<DeadlineReminderWorker> logger, IServiceScopeFactory scopeFactory)
    {
        _logger = logger;
        _scopeFactory = scopeFactory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("DeadlineReminderWorker is starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                _logger.LogInformation("DeadlineReminderWorker running at: {time}", DateTimeOffset.Now);
                
                using (var scope = _scopeFactory.CreateScope())
                {
                    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                    var eventPublisher = scope.ServiceProvider.GetRequiredService<IEventPublisher>();

                    var now = DateTime.UtcNow;
                    var twoHoursLater = now.AddHours(2);

                    // Find occurrences due in the next 2 hours that haven't been reminded
                    var occurrences = await dbContext.ChoreOccurrences
                        .Include(o => o.Chore)
                        .Where(o => o.Status == ChoreOccurrenceStatus.ASSIGNED 
                                    && o.AssignedUserId != null
                                    && !o.ReminderSent
                                    && o.DueDate > now
                                    && o.DueDate <= twoHoursLater)
                        .ToListAsync(stoppingToken);

                    var mutations = scope.ServiceProvider.GetRequiredService<IHouseMutationCoordinator>();
                    foreach (var candidate in occurrences) {
                        await mutations.RunAsync(candidate.Chore.HouseId,async () => {
                            var occurrence = await dbContext.ChoreOccurrences.Include(o=>o.Chore).Include(o=>o.Season).SingleAsync(o=>o.Id==candidate.Id,stoppingToken);
                            if (occurrence.ReminderSent || occurrence.AssignedUserId == null || occurrence.Status != ChoreOccurrenceStatus.ASSIGNED || occurrence.Season.Status != SeasonStatus.ACTIVE || occurrence.Season.StartDate > now) return;
                            occurrence.ReminderSent = true;
                            await eventPublisher.PublishAsync(new DeadlineReminderEvent(occurrence.Id,occurrence.AssignedUserId.Value,occurrence.Chore.HouseId),stoppingToken);
                        },stoppingToken);
                    }
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (ObjectDisposedException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred executing DeadlineReminderWorker.");
            }

            try { await Task.Delay(TimeSpan.FromMinutes(15), stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }
}
