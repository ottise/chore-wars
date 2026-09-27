using Microsoft.Extensions.DependencyInjection;
using ChoreWars.Presentation.Filters;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Presentation.Hubs;

namespace ChoreWars.Presentation.Extensions;

public static class PresentationServiceExtensions
{
    public static IServiceCollection AddPresentationServices(this IServiceCollection services)
    {
        services.AddControllers(options =>
        {
            options.Filters.Add<ValidationFilter>();
        });
        
        services.AddEndpointsApiExplorer();
        services.AddSignalR();
        services.AddScoped<INotificationRealtimePublisher, NotificationRealtimePublisher>();
        
        return services;
    }
}
