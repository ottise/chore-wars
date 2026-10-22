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
        services.AddSingleton(TimeProvider.System);
        services.AddScoped<IAIContextBuilder, ChoreWars.Application.Services.AI.AIContextBuilder>();
        services.AddScoped<IAIHousekeeperService, ChoreWars.Application.Services.AI.AIHousekeeperService>();
        services.AddScoped<IScheduleChangeService, ChoreWars.Application.Services.AI.ScheduleChangeService>();
        services.AddScoped<IEvidenceService, ChoreWars.Application.Services.AI.EvidenceService>();
        services.AddScoped<IUrgentPlanValidation, ChoreWars.Application.Services.AI.UrgentPlanValidation>();
        // AutoMapper
        services.AddAutoMapper(typeof(AuthService).Assembly);

        // FluentValidation
        services.AddValidatorsFromAssembly(typeof(RegisterRequestValidator).Assembly);

        services.AddScoped<IRewardService, RewardService>();
        services.AddScoped<IMediaService, MediaService>();
        services.AddScoped<IHouseAccessService, HouseAccessService>();
        services.AddScoped<IHouseholdResolutionService, HouseholdResolutionService>();
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
        services.AddScoped<IChatService, ChatService>();
        services.AddScoped<IActionProposalService, ActionProposalService>();

        return services;
    }
}
