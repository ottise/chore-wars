using System.Net;
using System.Net.Sockets;
using System.Text;
using ChoreWars.Infrastructure.Email;
using Microsoft.Extensions.Options;
namespace UnitTests.Services;
public class OrderEmailTransportTests
{
    [Fact]
    public async Task SmtpSenderActuallySendsAnOrderToTheConfiguredTransport()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0); listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var server = Task.Run(async () =>
        {
            using var client = await listener.AcceptTcpClientAsync(timeout.Token);
            await using var stream = client.GetStream(); using var reader = new StreamReader(stream, Encoding.ASCII);
            await using var writer = new StreamWriter(stream, Encoding.ASCII) { AutoFlush = true, NewLine = "\r\n" };
            await writer.WriteLineAsync("220 localhost test SMTP"); var data = new StringBuilder(); var receiving = false;
            while (!timeout.IsCancellationRequested)
            {
                var line = await reader.ReadLineAsync(timeout.Token); if (line == null) break;
                if (receiving) { if (line == ".") { await writer.WriteLineAsync("250 accepted"); receiving = false; } else data.AppendLine(line); }
                else if (line.StartsWith("EHLO") || line.StartsWith("HELO")) await writer.WriteLineAsync("250 localhost");
                else if (line.StartsWith("DATA")) { receiving = true; await writer.WriteLineAsync("354 send data"); }
                else if (line.StartsWith("QUIT")) { await writer.WriteLineAsync("221 bye"); break; }
                else await writer.WriteLineAsync("250 ok");
            }
            return data.ToString();
        }, timeout.Token);
        try
        {
            var sender = new SmtpSupplyOrderEmailSender(Options.Create(new SupplyOrderEmailOptions { Host = "127.0.0.1", Port = port,
                EnableSsl = false, FromAddress = "system@example.test" }));
            Assert.True(sender.IsConfigured);
            await sender.SendAsync(Guid.NewGuid(), "supplier@example.test", "Household order", "2 x Rice", timeout.Token);
            var content = await server;
            Assert.Contains("supplier@example.test", content); Assert.Contains("2 x Rice", content);
        }
        finally { listener.Stop(); }
    }
}
