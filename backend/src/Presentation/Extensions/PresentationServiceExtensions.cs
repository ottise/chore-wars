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
            options.Filters.Add<HouseScopeFilter>();
        });
        
        services.AddEndpointsApiExplorer();
        services.AddSignalR();
        services.AddSingleton<ChatConnectionRegistry>();
        services.AddScoped<IHouseRealtimeAccess, HouseRealtimeAccess>();
        services.AddScoped<INotificationRealtimePublisher, NotificationRealtimePublisher>();
        services.AddScoped<IActionProposalRealtimePublisher, ActionProposalRealtimePublisher>();
        services.AddScoped<ISupplyChatPublisher, SupplyChatPublisher>();
        
        return services;
    }
}
