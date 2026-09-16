using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Application.Validations.Auth;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;

namespace ChoreWars.Presentation.Extensions;

public static class ApplicationServiceExtensions
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        // AutoMapper
        services.AddAutoMapper(typeof(AuthService).Assembly);

        // FluentValidation
        services.AddValidatorsFromAssembly(typeof(RegisterRequestValidator).Assembly);

        // Services
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IHouseService, HouseService>();
        services.AddScoped<ISeasonService, SeasonService>();
        services.AddScoped<IChoreService, ChoreService>();
        services.AddScoped<IGamificationService, GamificationService>();
        services.AddScoped<IBountyService, BountyService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IOverduePenaltyService, OverduePenaltyService>();
        services.AddScoped<IBountyExpirationService, BountyExpirationService>();
        services.AddScoped<IChoreAllocationService, ChoreAllocationService>();
        services.AddScoped<IKarmaService, KarmaService>();
        services.AddScoped<ISeasonEndService, SeasonEndService>();
        services.AddScoped<IAchievementCheckService, AchievementCheckService>();
        services.AddScoped<IChoreGenerationService, ChoreGenerationService>();

        return services;
    }
}
