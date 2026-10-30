using System.Net;
using System.Text;
using System.Text.Json;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Email;
using Microsoft.Extensions.Configuration;
using Moq;

namespace UnitTests.Services;

public class AccountEmailTests
{
    private sealed class Handler(HttpStatusCode status, string response) : HttpMessageHandler
    {
        public string? Body;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Assert.Equal("https://api.brevo.com/v3/smtp/email", request.RequestUri!.AbsoluteUri);
            Assert.Equal("test-only-provider-key", Assert.Single(request.Headers.GetValues("api-key")));
            Body = await request.Content!.ReadAsStringAsync(ct);
            return new(status) { Content = new StringContent(response, Encoding.UTF8, "application/json") };
        }
    }
    [Theory]
    [InlineData(201, "{\"messageId\":\"accepted-test\"}", true)]
    [InlineData(403, "{}", false)]
    [InlineData(200, "{}", false)]
    public async Task HttpsOtpTransportRequiresActualProviderAcceptanceAndNeverFallsBackToSmtp(int status, string body, bool accepted)
    {
        var handler = new Handler((HttpStatusCode)status, body);
        var factory = new Mock<IHttpClientFactory>(); factory.Setup(x => x.CreateClient("account-email")).Returns(() => new HttpClient(handler, false));
        var smtp = new Mock<ISupplyOrderEmailSender>(MockBehavior.Strict);
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["AccountEmail:Provider"] = "Brevo",
            ["AccountEmail:ApiKey"] = "test-only-provider-key",
            ["AccountEmail:FromAddress"] = "sender@example.test"
        }).Build();
        var sender = new AccountEmailSender(factory.Object, config, smtp.Object);
        Assert.True(sender.IsConfigured);
        if (accepted) await sender.SendCodeAsync("recipient@example.test", "123456", "VERIFY_EMAIL", default);
        else await Assert.ThrowsAsync<InvalidOperationException>(() => sender.SendCodeAsync("recipient@example.test", "123456", "VERIFY_EMAIL", default));
        var payload = JsonSerializer.Deserialize<JsonElement>(handler.Body!);
        Assert.Equal("recipient@example.test", payload.GetProperty("to")[0].GetProperty("email").GetString());
        Assert.Contains("123456", payload.GetProperty("textContent").GetString());
        var html = payload.GetProperty("htmlContent").GetString();
        Assert.Contains("123456", html);
        Assert.Contains("Verify your email address", html);
        Assert.DoesNotContain("<script", html);
        smtp.VerifyNoOtherCalls();
    }
}
