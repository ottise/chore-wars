using System.Net;
using System.Net.Mail;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.Options;
namespace ChoreWars.Infrastructure.Email;
public sealed class SmtpSupplyOrderEmailSender(IOptions<SupplyOrderEmailOptions> options) : ISupplyOrderEmailSender
{
    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Value.Host)
        && options.Value.Port is > 0 and <= 65535 && MailAddress.TryCreate(options.Value.FromAddress, out _)
        && (string.IsNullOrWhiteSpace(options.Value.Username) || !string.IsNullOrWhiteSpace(options.Value.Password));
    public async Task SendAsync(Guid dispatchId, string recipient, string subject, string body, CancellationToken ct)
    {
        if (!IsConfigured) throw new InvalidOperationException("Order email is not configured.");
        var config = options.Value;
        using var client = new SmtpClient(config.Host, config.Port) { EnableSsl = config.EnableSsl, UseDefaultCredentials = false };
        if (!string.IsNullOrWhiteSpace(config.Username)) client.Credentials = new NetworkCredential(config.Username, config.Password);
        using var message = new MailMessage(new MailAddress(config.FromAddress, config.FromName), new MailAddress(recipient))
        { Subject = subject, Body = body, IsBodyHtml = false };
        message.Headers.Add("X-Chore-Wars-Dispatch", dispatchId.ToString());
        await client.SendMailAsync(message, ct);
    }
}
