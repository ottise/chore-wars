using System.Net;
using System.Net.Http.Json;

namespace IntegrationTests.Infrastructure;

public sealed class AuthRateLimitTests
{
    [PostgresFact]
    public async Task PasswordAuthBurstStopsAtTwentyAndReturnsRetryAfter()
    {
        await using var database = await PostgresFixture.CreateAsync();
        using var factory = new ApiFactory(database); using var client = factory.CreateClient();
        for (var i = 0; i < 20; i++)
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/auth/login", new { email = "not-an-account@example.test", password = "WrongPassword1!" })).StatusCode);
        var rejected = await client.PostAsJsonAsync("/api/auth/login", new { email = "not-an-account@example.test", password = "WrongPassword1!" });
        Assert.Equal(HttpStatusCode.TooManyRequests, rejected.StatusCode);
        Assert.NotNull(rejected.Headers.RetryAfter);
        Assert.Contains("Please wait", await rejected.Content.ReadAsStringAsync());
    }
}
