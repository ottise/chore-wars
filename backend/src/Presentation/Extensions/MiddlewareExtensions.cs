using Microsoft.AspNetCore.Builder;
using ChoreWars.Presentation.Middleware;
using ChoreWars.Presentation.Hubs;

namespace ChoreWars.Presentation.Extensions;

public static class MiddlewareExtensions
{
    public static IApplicationBuilder UseCustomMiddleware(this IApplicationBuilder app)
    {
        app.UseMiddleware<GlobalExceptionMiddleware>();
        return app;
    }

    public static WebApplication MapPresentationEndpoints(this WebApplication app)
    {
        app.MapControllers();
        app.MapHub<NotificationHub>("/hubs/notification");
        
        return app;
    }
}
