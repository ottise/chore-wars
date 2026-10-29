using System.Net.Http.Json;
using System.Net.Mail;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.Configuration;

namespace ChoreWars.Infrastructure.Email;

public sealed class AccountEmailSender(IHttpClientFactory clients, IConfiguration config,
    ISupplyOrderEmailSender smtp) : IAccountEmailSender
{
    private bool Brevo => string.Equals(config["AccountEmail:Provider"], "Brevo", StringComparison.OrdinalIgnoreCase);
    public bool IsConfigured => Brevo ? !string.IsNullOrWhiteSpace(config["AccountEmail:ApiKey"]) &&
        MailAddress.TryCreate(config["AccountEmail:FromAddress"], out _) :
        (string.IsNullOrWhiteSpace(config["AccountEmail:Provider"]) || string.Equals(config["AccountEmail:Provider"], "SMTP", StringComparison.OrdinalIgnoreCase)) && smtp.IsConfigured;

    public async Task SendCodeAsync(string email, string code, string purpose, CancellationToken ct)
    {
        if (!IsConfigured) throw new InvalidOperationException("Account email is not configured.");
        var subject = purpose == "VERIFY_EMAIL" ? "Verify your Chore Wars email" : "Reset your Chore Wars password";
        var body = $"Your Chore Wars code is {code}. It expires in 10 minutes. Do not share this code. If you did not request it, ignore this email.";
        if (!Brevo) { await smtp.SendAsync(Guid.NewGuid(), email, subject, body, ct); return; }
        using var client = clients.CreateClient("account-email");
        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.brevo.com/v3/smtp/email");
        request.Headers.Add("api-key", config["AccountEmail:ApiKey"]);
        request.Content = JsonContent.Create(new { sender = new { email = config["AccountEmail:FromAddress"], name = "Chore Wars" },
            to = new[] { new { email } }, subject, textContent = body });
        using var response = await client.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException("Account email provider rejected the request.");
        var accepted = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>(ct);
        if (!accepted.TryGetProperty("messageId", out var id) || string.IsNullOrWhiteSpace(id.GetString()))
            throw new InvalidOperationException("Account email provider did not confirm acceptance.");
    }
}
