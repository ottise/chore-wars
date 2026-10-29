using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using ChoreWars.Application.DTOs.Auth;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Moq;

namespace IntegrationTests.Infrastructure;

public class GoogleHttpTests
{
    [PostgresFact]
    public async Task GoogleExchangeRejectsInvalidIdentityAndIssuesUsableSessionForVerifiedIdentity()
    {
        await using var database = await PostgresFixture.CreateAsync();
        var verifier = new Mock<IGoogleIdentityVerifier>(MockBehavior.Strict);
        verifier.Setup(x => x.VerifyAsync("verified-test-identity", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new GoogleIdentity("http-google-subject", "google-http@example.test", "Google HTTP", null));
        verifier.Setup(x => x.VerifyAsync("invalid-test-identity", It.IsAny<CancellationToken>()))
            .ThrowsAsync(new ForbiddenException("Google identity could not be verified."));
        using var root = new ApiFactory(database);
        using var factory = root.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<IGoogleIdentityVerifier>();
            services.AddSingleton(verifier.Object);
        }));
        using var client = factory.CreateClient();
        var invalid = await client.PostAsJsonAsync("/api/auth/google", new GoogleLoginRequest("invalid-test-identity"));
        Assert.Equal(HttpStatusCode.Forbidden, invalid.StatusCode);
        var login = await client.PostAsJsonAsync("/api/auth/google", new GoogleLoginRequest("verified-test-identity"));
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var session = await login.Content.ReadFromJsonAsync<LoginResponse>();
        Assert.NotNull(session);
        Assert.NotEmpty(session.Token);
        Assert.NotEmpty(session.RefreshToken);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.Token);
        var houses = await client.GetAsync("/api/houses/my-houses");
        Assert.Equal(HttpStatusCode.OK, houses.StatusCode);
        await using var scope = database.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = Assert.Single(await db.Users.ToListAsync());
        Assert.Equal(session.UserId, user.Id);
        Assert.Equal("http-google-subject", user.GoogleSubject);
        Assert.Empty(user.PasswordHash);
        Assert.Empty(await db.HouseMembers.ToListAsync());
    }
}
