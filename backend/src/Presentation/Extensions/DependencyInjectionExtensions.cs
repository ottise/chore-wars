using System.Text;
using FluentValidation;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using StackExchange.Redis;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Application.Validations.Auth;
using ChoreWars.Infrastructure.Auth;
using ChoreWars.Infrastructure.Cache.Redis;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Messaging.Kafka;
using ChoreWars.Infrastructure.Repositories;
using ChoreWars.Infrastructure.Workers;

namespace ChoreWars.Presentation.Extensions;

public static class DependencyInjectionExtensions
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
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
        
        services.AddHostedService<ChoreWars.Infrastructure.Messaging.Kafka.Consumers.ChoreCompletedConsumer>();
        services.AddHostedService<ChoreWars.Infrastructure.Messaging.Kafka.Consumers.BountyCreatedConsumer>();
        services.AddHostedService<ChoreWars.Infrastructure.Messaging.Kafka.Consumers.ChoreOverdueConsumer>();
        services.AddHostedService<ChoreWars.Infrastructure.Messaging.Kafka.Consumers.SeasonEndedConsumer>();

        return services;
    }

    public static IServiceCollection AddApplication(this IServiceCollection services)
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
        services.AddScoped<ISeasonEndService, SeasonEndService>();
        services.AddScoped<IAchievementCheckService, AchievementCheckService>();

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
