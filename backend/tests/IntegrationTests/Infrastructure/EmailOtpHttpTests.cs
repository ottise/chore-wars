using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace IntegrationTests.Infrastructure;

public class EmailOtpHttpTests
{
    [PostgresFact]
    public async Task MissingEmailTransportDoesNotCreateAnUnverifiablePasswordAccount()
    {
        await using var f = await PostgresFixture.CreateAsync(new() { ["EmailVerification:Required"] = "true" });
        await using var scope = f.Services.CreateAsyncScope();
        await Assert.ThrowsAsync<ChoreWars.Domain.Exceptions.ConflictException>(() => scope.ServiceProvider.GetRequiredService<IAuthService>()
            .RegisterAsync(new() { Email = "missing-mail@example.test", DisplayName = "New user", Password = "Password1!" }));
        Assert.Empty(await scope.ServiceProvider.GetRequiredService<AppDbContext>().Users.ToListAsync());
    }
    private sealed class Mailbox : IAccountEmailSender
    {
        public bool IsConfigured => true;
        public List<(string Email, string Code, string Purpose)> Messages { get; } = [];
        public Task SendCodeAsync(string email, string code, string purpose, CancellationToken ct)
        { Messages.Add((email, code, purpose)); return Task.CompletedTask; }
    }
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now = DateTimeOffset.UtcNow;
        public override DateTimeOffset GetUtcNow() => Now;
    }
    [PostgresFact]
    public async Task RegistrationVerificationAndPasswordResetUseSingleUsePurposeBoundCodes()
    {
        await using var db = await PostgresFixture.CreateAsync();
        using var root = new ApiFactory(db); var mailbox = new Mailbox();
        using var factory = root.WithWebHostBuilder(b => {
            b.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> { ["EmailVerification:Required"] = "true" }));
            b.ConfigureTestServices(s => { s.RemoveAll<IAccountEmailSender>(); s.AddSingleton<IAccountEmailSender>(mailbox); });
        });
        using var client = factory.CreateClient();
        var email = "otp@example.test";
        var oldPassword = "OldPassword1!";
        (await client.PostAsJsonAsync("/api/auth/register", new { email, password = oldPassword, displayName = "OTP user" })).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/auth/login", new { email, password = oldPassword })).StatusCode);
        var request = new { email, purpose = "VERIFY_EMAIL" };
        (await client.PostAsJsonAsync("/api/auth/email-otp/request", request)).EnsureSuccessStatusCode();
        var code = Assert.Single(mailbox.Messages).Code;
        (await client.PostAsJsonAsync("/api/auth/email-otp/request", request)).EnsureSuccessStatusCode();
        Assert.Single(mailbox.Messages);
        (await client.PostAsJsonAsync("/api/auth/email-otp/verify", new { email, code })).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/auth/email-otp/verify", new { email, code })).StatusCode);
        var login = await client.PostAsJsonAsync("/api/auth/login", new { email, password = oldPassword }); login.EnsureSuccessStatusCode();
        var refreshToken = (await login.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("refreshToken").GetString();
        (await client.PostAsJsonAsync("/api/auth/email-otp/request", new { email = "unknown@example.test", purpose = "RESET_PASSWORD" })).EnsureSuccessStatusCode();
        Assert.Single(mailbox.Messages);
        (await client.PostAsJsonAsync("/api/auth/email-otp/request", new { email, purpose = "RESET_PASSWORD" })).EnsureSuccessStatusCode();
        var reset = mailbox.Messages.Last().Code;
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/auth/email-otp/verify", new { email, code = reset })).StatusCode);
        (await client.PostAsJsonAsync("/api/auth/password/reset", new { email, code = reset, newPassword = "NewPassword1!" })).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/auth/refresh-token", new { refreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/auth/login", new { email, password = oldPassword })).StatusCode);
        (await client.PostAsJsonAsync("/api/auth/login", new { email, password = "NewPassword1!" })).EnsureSuccessStatusCode();
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.NotNull((await context.Users.SingleAsync()).EmailVerifiedAt);
        Assert.All(await context.EmailOtpChallenges.Select(x => x.CodeHash).ToListAsync(), hash => Assert.Equal(64, hash.Length));
    }

    [PostgresFact]
    public async Task TooManyGuessesExpiryAndResendInvalidateCodes()
    {
        var mailbox = new Mailbox(); var clock = new Clock();
        await using var db = await PostgresFixture.CreateAsync(new() { ["Jwt:Secret"] = "isolated-otp-test-signing-key-not-production-000000000", ["EmailVerification:Required"] = "true" }, s => {
            s.AddSingleton<IAccountEmailSender>(mailbox); s.AddSingleton<TimeProvider>(clock);
        });
        await using (var scope = db.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<IAuthService>().RegisterAsync(new() { Email = "guess@example.test", Password = "Password1!", DisplayName = "Guess" });
        async Task Request() { await using var s = db.Services.CreateAsyncScope(); await s.ServiceProvider.GetRequiredService<IEmailOtpService>().RequestAsync("guess@example.test", "VERIFY_EMAIL", default); }
        async Task Verify(string code) { await using var s = db.Services.CreateAsyncScope(); await s.ServiceProvider.GetRequiredService<IEmailOtpService>().VerifyAsync("guess@example.test", code, null, default); }
        await Request(); var original = mailbox.Messages.Last().Code;
        var wrong = original == "000000" ? "111111" : "000000";
        for (var i = 0; i < 5; i++) await Assert.ThrowsAsync<ChoreWars.Domain.Exceptions.ForbiddenException>(() => Verify(wrong));
        await Assert.ThrowsAsync<ChoreWars.Domain.Exceptions.ForbiddenException>(() => Verify(original));
        clock.Now = clock.Now.AddMinutes(1); await Request();
        clock.Now = clock.Now.AddMinutes(11);
        await Assert.ThrowsAsync<ChoreWars.Domain.Exceptions.ForbiddenException>(() => Verify(mailbox.Messages.Last().Code));
        await Request(); await Verify(mailbox.Messages.Last().Code);
    }
}
