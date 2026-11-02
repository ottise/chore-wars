using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using Google.Apis.Auth.OAuth2;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Infrastructure.Messaging;

public sealed class FirebasePushNotificationPublisher(
    AppDbContext db,
    IHttpClientFactory httpClientFactory,
    IConfiguration configuration,
    ILogger<FirebasePushNotificationPublisher> logger) : IPushNotificationPublisher
{
    private const string MessagingScope = "https://www.googleapis.com/auth/firebase.messaging";

    public async Task PublishAsync(NotificationResponse notification, CancellationToken cancellationToken = default)
    {
        var projectId = configuration["Firebase:ProjectId"];
        var credentialsPath = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
        if (string.IsNullOrWhiteSpace(projectId) || string.IsNullOrWhiteSpace(credentialsPath))
        {
            logger.LogDebug("Firebase push is not configured; notification {NotificationId} remains available in the app inbox.", notification.Id);
            return;
        }

        if (!File.Exists(credentialsPath))
        {
            logger.LogWarning("Firebase service account file is missing at the configured secret path.");
            return;
        }

        var tokens = await db.PushDeviceTokens
            .Where(x => x.UserId == notification.UserId)
            .Select(x => x.Token)
            .ToListAsync(cancellationToken);
        if (tokens.Count == 0) return;

        var credential = GoogleCredential.FromFile(credentialsPath).CreateScoped(MessagingScope);
        var accessToken = await credential.UnderlyingCredential.GetAccessTokenForRequestAsync(null, cancellationToken);
        var client = httpClientFactory.CreateClient("firebase-cloud-messaging");
        foreach (var token in tokens)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post,
                $"https://fcm.googleapis.com/v1/projects/{Uri.EscapeDataString(projectId)}/messages:send");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
            request.Content = new StringContent(JsonSerializer.Serialize(new
            {
                message = new
                {
                    token,
                    notification = new { title = notification.Title, body = notification.Message },
                    data = new Dictionary<string, string>
                    {
                        ["notificationId"] = notification.Id.ToString(),
                        ["houseId"] = notification.HouseId.ToString(),
                        ["type"] = notification.Type.ToString(),
                        ["targetType"] = notification.TargetType ?? string.Empty,
                        ["targetId"] = notification.TargetId?.ToString() ?? string.Empty
                    },
                    android = new { priority = "HIGH" }
                }
            }), Encoding.UTF8, "application/json");

            using var response = await client.SendAsync(request, cancellationToken);
            if (response.IsSuccessStatusCode) continue;

            var responseText = await response.Content.ReadAsStringAsync(cancellationToken);
            if (response.StatusCode == System.Net.HttpStatusCode.NotFound || responseText.Contains("UNREGISTERED", StringComparison.OrdinalIgnoreCase))
            {
                var stale = await db.PushDeviceTokens.FirstOrDefaultAsync(x => x.Token == token, cancellationToken);
                if (stale != null)
                {
                    db.PushDeviceTokens.Remove(stale);
                    await db.SaveChangesAsync(cancellationToken);
                }
                continue;
            }

            logger.LogWarning("Firebase push delivery failed with status {StatusCode}.", (int)response.StatusCode);
        }
    }
}
