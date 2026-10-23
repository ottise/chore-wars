using System.Text;
using System.Threading.Tasks;
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
        var databaseConnectionString = configuration.GetConnectionString("DefaultConnection");
        if (string.IsNullOrWhiteSpace(databaseConnectionString))
        {
            throw new InvalidOperationException(
                "Connection string 'DefaultConnection' is missing. Configure ConnectionStrings__DefaultConnection or appsettings for the current environment.");
        }

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(databaseConnectionString));

        services.Configure<ChoreWars.Infrastructure.AI.AIOptions>(configuration.GetSection("AI"));
        services.AddSingleton<IAIServiceStatus, ChoreWars.Infrastructure.AI.AIServiceStatus>();
        services.AddScoped<IAIStateRepository, AIStateRepository>();
        services.AddHostedService<ChoreWars.Infrastructure.AI.AIChatInsightWorker>();
        services.AddHttpClient<IAIHousekeeperClient, ChoreWars.Infrastructure.AI.AIHousekeeperHttpClient>(http => {
            http.BaseAddress = new Uri(configuration["AI:BaseUrl"] ?? "http://ai-api:8000");
            http.Timeout = TimeSpan.FromSeconds(configuration.GetValue<int?>("AI:RequestTimeoutSeconds") ?? 30);
        });

        services.AddScoped<IAfterCommitActions, ChoreWars.Infrastructure.Concurrency.AfterCommitActions>();
        services.AddSingleton<ChoreWars.Infrastructure.Diagnostics.IRuntimeProbe, ChoreWars.Infrastructure.Diagnostics.NoopRuntimeProbe>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<IHouseMutationCoordinator, ChoreWars.Infrastructure.Concurrency.PostgresHouseMutationCoordinator>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<IHouseRepository, HouseRepository>();
        services.AddScoped<IHouseMemberRepository, HouseMemberRepository>();
        services.AddScoped<IChoreSeasonRepository, ChoreSeasonRepository>();
        services.AddScoped<IMemberAvailabilityRepository, MemberAvailabilityRepository>();
        services.AddScoped<IMemberPreferenceRepository, MemberPreferenceRepository>();
        services.AddScoped<IMemberConstraintRepository, MemberConstraintRepository>();
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
        services.AddScoped<IChatRepository, ChatRepository>();
        services.AddScoped<IActionProposalRepository, ActionProposalRepository>();

        services.Configure<ChoreWars.Infrastructure.Storage.MediaStorageOptions>(configuration.GetSection("MediaStorage"));
        services.AddScoped<IMediaStorage, ChoreWars.Infrastructure.Storage.FileMediaStorage>();

        // Redis
        var redisConnStr = configuration["Redis:ConnectionString"] ?? "localhost:6379";
        var redisOptions = ConfigurationOptions.Parse(redisConnStr);
        redisOptions.AbortOnConnectFail = false;
        redisOptions.ConnectTimeout = 2000;
        services.AddSingleton<IConnectionMultiplexer>(_ => ConnectionMultiplexer.Connect(redisOptions));
        services.AddSingleton<ICacheService, RedisCacheService>();

        // Kafka
        services.Configure<KafkaOptions>(configuration.GetSection("Kafka"));
        services.AddScoped<IEventPublisher, ChoreWars.Infrastructure.Messaging.OutboxEventPublisher>();
        services.AddScoped<IFailedEventService, ChoreWars.Infrastructure.Messaging.Recovery.FailedEventService>();
        services.AddHostedService<OutboxDispatcherWorker>();
        services.AddHostedService<MediaCleanupWorker>();

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
        services.AddHostedService<ChatMessageCreatedConsumer>();
        services.AddHostedService<BountyCreatedConsumer>();
        services.AddHostedService<BountyAcceptedConsumer>();
        services.AddHostedService<ChoreOverdueConsumer>();
        services.AddHostedService<BountyExpiredConsumer>();
        services.AddHostedService<SeasonEndedConsumer>();
        services.AddHostedService<DeadlineReminderConsumer>();

        return services;
    }

    public static IServiceCollection AddJwtAuthentication(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                var secret = configuration["Jwt:Secret"] ?? "a-very-long-fallback-secret-key-that-should-be-replaced";
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

                options.Events = new JwtBearerEvents
                {
                    OnMessageReceived = context =>
                    {
                        var accessToken = context.Request.Query["access_token"];
                        var path = context.HttpContext.Request.Path;
                        if (!string.IsNullOrEmpty(accessToken) &&
                            (path.StartsWithSegments("/api/chat-hub") ||
                             path.StartsWithSegments("/chat-hub") ||
                             path.StartsWithSegments("/hubs") ||
                             path.StartsWithSegments("/api/notifications")))
                        {
                            context.Token = accessToken;
                        }
                        return Task.CompletedTask;
                    }
                };
            });

        return services;
    }
}
