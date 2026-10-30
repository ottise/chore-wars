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

    public static string BuildHtml(string code, string purpose)
    {
        var reset = purpose == "RESET_PASSWORD";
        var title = reset ? "Reset your password" : "Verify your email address";
        var intro = reset ? "Enter this verification code in Chore Wars to choose a new password." : "Welcome to Chore Wars. Enter this verification code in the app to activate your household account.";
        var safeCode = System.Net.WebUtility.HtmlEncode(code);
        return $"""
            <!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
            <body style="margin:0;background:#f7f6fa;font-family:Arial,Helvetica,sans-serif;color:#282331">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center" style="padding:32px 16px">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px"><tr><td style="padding:0 16px 24px;color:#6545d9;font-size:22px;font-weight:bold">⌂ Chore Wars</td></tr>
            <tr><td align="center" style="background:#ffffff;border-radius:24px;padding:36px 24px">
            <p style="color:#6545d9;font-size:12px">Account security</p>
            <h1 style="font-size:24px;margin:16px 0">{title}</h1>
            <p style="color:#70697b;font-size:15px;line-height:1.7">{intro}</p>
            <table role="presentation" width="100%" style="margin:24px 0;background:#f8f6fc;border:1px solid #ece7f6;border-radius:16px"><tr><td align="center" style="padding:24px">
            <p style="color:#70697b;font-size:12px;margin:0 0 12px">One-time passcode</p>
            <p style="color:#6545d9;font-family:monospace;font-size:36px;letter-spacing:8px;font-weight:bold;margin:0">{safeCode}</p>
            </td></tr></table>
            <p style="color:#8a5700;background:#fffbef;border:1px solid #f6e8bf;border-radius:16px;padding:10px;font-size:13px">This code expires in 10 minutes.</p>
            <p style="color:#70697b;font-size:13px;line-height:1.6;margin-top:28px">Do not share this code. If you did not request it, you can safely ignore this email.</p>
            </td></tr><tr><td align="center" style="padding:20px;color:#70697b;font-size:12px">Chore Wars · Chores, together.</td></tr></table>
            </td></tr></table></body></html>
            """;
    }

    public async Task SendCodeAsync(string email, string code, string purpose, CancellationToken ct)
    {
        if (!IsConfigured) throw new InvalidOperationException("Account email is not configured.");
        var subject = purpose == "VERIFY_EMAIL" ? "Verify your Chore Wars email" : "Reset your Chore Wars password";
        var body = $"Your Chore Wars code is {code}. It expires in 10 minutes. Do not share this code. If you did not request it, ignore this email.";
        if (!Brevo) { await smtp.SendAsync(Guid.NewGuid(), email, subject, body, ct); return; }
        using var client = clients.CreateClient("account-email");
        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.brevo.com/v3/smtp/email");
        request.Headers.Add("api-key", config["AccountEmail:ApiKey"]);
        request.Content = JsonContent.Create(new
        {
            sender = new { email = config["AccountEmail:FromAddress"], name = "Chore Wars" },
            to = new[] { new { email } },
            subject,
            textContent = body,
            htmlContent = BuildHtml(code, purpose)
        });
        using var response = await client.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException("Account email provider rejected the request.");
        var accepted = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>(ct);
        if (!accepted.TryGetProperty("messageId", out var id) || string.IsNullOrWhiteSpace(id.GetString()))
            throw new InvalidOperationException("Account email provider did not confirm acceptance.");
    }
}
