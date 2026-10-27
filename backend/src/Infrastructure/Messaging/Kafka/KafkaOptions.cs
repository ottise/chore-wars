using Confluent.Kafka;

namespace ChoreWars.Infrastructure.Messaging.Kafka;

public class KafkaOptions
{
    public string BootstrapServers { get; set; } = string.Empty;
    public string ConsumerGroupId { get; set; } = "chore-wars-group";
    public string TopicPrefix { get; set; } = "";
    public int SessionTimeoutMs { get; set; } = 45000;
    public SecurityProtocol SecurityProtocol { get; set; } = SecurityProtocol.Plaintext;
    public SaslMechanism SaslMechanism { get; set; } = SaslMechanism.Plain;
    public string? SaslUsername { get; set; }
    public string? SaslPassword { get; set; }
    public string? SslCaLocation { get; set; }
    public string? SslCaPem { get; set; }

    public ClientConfig ConnectionConfig()
    {
        if (SecurityProtocol == SecurityProtocol.SaslPlaintext)
            throw new InvalidOperationException("Kafka SASL authentication requires TLS. Configure Kafka__SecurityProtocol=SaslSsl.");
        if (SecurityProtocol == SecurityProtocol.SaslSsl &&
            (string.IsNullOrWhiteSpace(SaslUsername) || string.IsNullOrWhiteSpace(SaslPassword)))
            throw new InvalidOperationException("Configure Kafka__SaslUsername and Kafka__SaslPassword for the SASL broker.");

        var config = new ClientConfig { BootstrapServers = BootstrapServers, SecurityProtocol = SecurityProtocol };
        if (SecurityProtocol == SecurityProtocol.SaslSsl)
        {
            config.SaslMechanism = SaslMechanism;
            config.SaslUsername = SaslUsername;
            config.SaslPassword = SaslPassword;
        }
        if (SecurityProtocol is SecurityProtocol.Ssl or SecurityProtocol.SaslSsl)
        {
            config.EnableSslCertificateVerification = true;
            config.SslEndpointIdentificationAlgorithm = SslEndpointIdentificationAlgorithm.Https;
            if (!string.IsNullOrWhiteSpace(SslCaLocation)) config.SslCaLocation = SslCaLocation;
            if (!string.IsNullOrWhiteSpace(SslCaPem)) config.SslCaPem = SslCaPem;
        }
        return config;
    }
}
