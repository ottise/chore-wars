using ChoreWars.Application.DTOs.Auth;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;

namespace IntegrationTests.Infrastructure;

public class GoogleAuthTests
{
    private static Task<PostgresFixture> Fixture(string email = "new-google@example.com") => PostgresFixture.CreateAsync(
        new() { ["Jwt:Secret"] = "disposable-integration-test-key-google-identity-00000000000" },
        services =>
        {
            var verifier = new Mock<IGoogleIdentityVerifier>();
            verifier.Setup(x => x.VerifyAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
                .ReturnsAsync((string token, CancellationToken _) => new GoogleIdentity(token, email, "Google name", null));
            services.AddScoped(_ => verifier.Object);
        });

    [PostgresFact]
    public async Task ConcurrentGoogleLoginsCreateOneUserAndIndependentRefreshSessions()
    {
        await using var fixture = await Fixture();
        async Task<LoginResponse> Login()
        {
            await using var scope = fixture.Services.CreateAsyncScope();
            return await scope.ServiceProvider.GetRequiredService<IGoogleAuthService>().LoginAsync(new("subject-123"), default);
        }
        var sessions = await Task.WhenAll(Login(), Login());
        Assert.Equal(sessions[0].UserId, sessions[1].UserId);
        Assert.NotEqual(sessions[0].RefreshToken, sessions[1].RefreshToken);
        await using var scope = fixture.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = Assert.Single(await db.Users.ToListAsync());
        Assert.Equal("subject-123", user.GoogleSubject);
        Assert.Empty(user.PasswordHash);
        Assert.Equal(2, await db.RefreshTokens.CountAsync());
        Assert.Empty(await db.HouseMembers.ToListAsync());
        await Assert.ThrowsAsync<ForbiddenException>(() => scope.ServiceProvider.GetRequiredService<IAuthService>()
            .LoginAsync(new LoginRequest { Email = user.Email, Password = "anything" }, default));
    }

    [PostgresFact]
    public async Task ExistingEmailRequiresExplicitLinkAndKeepsHouseAndProfile()
    {
        await using var fixture = await Fixture("user0@test.local");
        var seed = await CoreConcurrencyTests.Seed(fixture);
        await using var scope = fixture.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.SingleAsync(x => x.Id == seed.Users[0]);
        // Use the fixture's actual email to avoid coupling this test to seed labels.
        user.Email = "user0@test.local";
        user.DisplayName = "My chosen name";
        var originalHash = user.PasswordHash;
        await db.SaveChangesAsync();
        var service = scope.ServiceProvider.GetRequiredService<IGoogleAuthService>();
        await Assert.ThrowsAsync<ConflictException>(() => service.LoginAsync(new("subject-123"), default));
        Assert.Null(user.GoogleSubject);
        await service.LinkAsync(user.Id, new("subject-123"), default);
        await service.LinkAsync(user.Id, new("subject-123"), default);
        var session = await service.LoginAsync(new("subject-123"), default);
        Assert.Equal(user.Id, session.UserId);
        Assert.Equal("My chosen name", session.DisplayName);
        Assert.Equal(originalHash, user.PasswordHash);
        Assert.Equal(1, await db.HouseMembers.CountAsync(x => x.UserId == user.Id && x.HouseId == seed.HouseId));
        Assert.True((await scope.ServiceProvider.GetRequiredService<IAuthService>().GetProfileAsync(user.Id)).GoogleLinked);
    }

    [PostgresFact]
    public async Task LinkRejectsDifferentEmailOrReplacingAnExistingSubject()
    {
        await using var fixture = await Fixture();
        var seed = await CoreConcurrencyTests.Seed(fixture);
        await using var scope = fixture.Services.CreateAsyncScope();
        var service = scope.ServiceProvider.GetRequiredService<IGoogleAuthService>();
        await Assert.ThrowsAsync<ForbiddenException>(() => service.LinkAsync(seed.Users[0], new("subject-123"), default));
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.SingleAsync(x => x.Id == seed.Users[0]);
        user.Email = "new-google@example.com"; user.GoogleSubject = "already-linked";
        await db.SaveChangesAsync();
        await Assert.ThrowsAsync<ConflictException>(() => service.LinkAsync(user.Id, new("replacement-subject"), default));
        Assert.Equal("already-linked", user.GoogleSubject);
        Assert.Empty(await db.RefreshTokens.ToListAsync());
    }
}
