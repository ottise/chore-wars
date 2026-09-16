using Microsoft.Extensions.DependencyInjection;
using ChoreWars.Presentation.Filters;

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
        
        return services;
    }
}
