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

                    foreach (var occurrence in occurrences)
                    {
                        occurrence.ReminderSent = true;
                        
                        // Publish event to Kafka
                        var reminderEvent = new DeadlineReminderEvent(occurrence.Id, occurrence.AssignedUserId.Value, occurrence.Chore.HouseId);
                        await eventPublisher.PublishAsync(reminderEvent, stoppingToken);

                        _logger.LogInformation($"Sent deadline reminder for ChoreOccurrence {occurrence.Id}");
                    }

                    if (occurrences.Any())
                    {
                        await dbContext.SaveChangesAsync(stoppingToken);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred executing DeadlineReminderWorker.");
            }

            await Task.Delay(TimeSpan.FromMinutes(15), stoppingToken);
        }
    }
}
