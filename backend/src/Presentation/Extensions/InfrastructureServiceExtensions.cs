using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using StackExchange.Redis;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Auth;
using ChoreWars.Infrastructure.Cache.Redis;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
using ChoreWars.Infrastructure.Messaging.Kafka.Consumers;
using ChoreWars.Infrastructure.Repositories;
using ChoreWars.Infrastructure.Workers;

namespace ChoreWars.Presentation.Extensions;

public static class InfrastructureServiceExtensions
{
    public static IServiceCollection AddInfrastructureServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection")));

        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<IHouseRepository, HouseRepository>();
        services.AddScoped<IHouseMemberRepository, HouseMemberRepository>();
        services.AddScoped<IChoreSeasonRepository, ChoreSeasonRepository>();
        services.AddScoped<IMemberAvailabilityRepository, MemberAvailabilityRepository>();
        services.AddScoped<ISeasonRankingRepository, SeasonRankingRepository>();
        services.AddScoped<IChoreRepository, ChoreRepository>();
        services.AddScoped<IChoreFrequencyDayRepository, ChoreFrequencyDayRepository>();
        services.AddScoped<IChoreOccurrenceRepository, ChoreOccurrenceRepository>();
        services.AddScoped<IKarmaTransactionRepository, KarmaTransactionRepository>();
        services.AddScoped<IRewardRepository, RewardRepository>();
        services.AddScoped<IRewardRedemptionRepository, RewardRedemptionRepository>();
        services.AddScoped<IAchievementRepository, AchievementRepository>();
        services.AddScoped<IUserAchievementRepository, UserAchievementRepository>();
        services.AddScoped<ISeasonConfirmationRepository, SeasonConfirmationRepository>();
        services.AddScoped<IChoreBountyRepository, ChoreBountyRepository>();
        services.AddScoped<IPaymentObligationRepository, PaymentObligationRepository>();
        services.AddScoped<INotificationRepository, NotificationRepository>();

        // Redis
        var redisConnStr = configuration["Redis:ConnectionString"] ?? "localhost:6379";
        services.AddSingleton<IConnectionMultiplexer>(ConnectionMultiplexer.Connect(redisConnStr));
        services.AddSingleton<ICacheService, RedisCacheService>();

        // Kafka
        services.Configure<KafkaOptions>(configuration.GetSection("Kafka"));
        services.AddSingleton<IEventPublisher, KafkaEventPublisher>();

        // Auth
        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<IAuthTokenProvider, JwtTokenProvider>();

        // Workers
        services.AddHostedService<ChoreAllocationWorker>();
        services.AddHostedService<OverdueChoreWorker>();
        services.AddHostedService<SeasonEndWorker>();
        services.AddHostedService<BountyExpirationWorker>();
        services.AddHostedService<DeadlineReminderWorker>();
        
        services.AddHostedService<ChoreCompletedConsumer>();
        services.AddHostedService<BountyCreatedConsumer>();
        services.AddHostedService<ChoreOverdueConsumer>();
        services.AddHostedService<BountyExpiredConsumer>();
        services.AddHostedService<SeasonEndedConsumer>();
        services.AddHostedService<DeadlineReminderConsumer>();

        return services;
    }

    public static IServiceCollection AddJwtAuthentication(this IServiceCollection services, IConfiguration configuration)
    {
        var secret = configuration["Jwt:Secret"] ?? "a-very-long-fallback-secret-key-that-should-be-replaced";
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = configuration["Jwt:Issuer"] ?? "ChoreWars",
                    ValidAudience = configuration["Jwt:Audience"] ?? "ChoreWarsUsers",
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret))
                };
            });

        return services;
    }
}
