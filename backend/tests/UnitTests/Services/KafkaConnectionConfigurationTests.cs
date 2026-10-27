using ChoreWars.Infrastructure.Messaging.Kafka;
using Confluent.Kafka;

namespace UnitTests.Services;

public sealed class KafkaConnectionConfigurationTests
{
    [Fact]
    public void LocalDockerRequiresNoCloudCredentials()
    {
        var config = new KafkaOptions { BootstrapServers = "kafka:9092" }.ConnectionConfig();
        Assert.Equal(SecurityProtocol.Plaintext, config.SecurityProtocol);
        Assert.Null(config.SaslPassword);
    }

    [Fact]
    public void CloudProducerAndConsumerShareVerifiedTlsAndCredentials()
    {
        var options = new KafkaOptions
        {
            BootstrapServers = "broker.example:19153",
            SecurityProtocol = SecurityProtocol.SaslSsl,
            SaslUsername = "test-user", SaslPassword = "test-password",
            SslCaLocation = "/etc/secrets/kafka-ca.pem"
        };
        var clients = new ClientConfig[] { new ProducerConfig(options.ConnectionConfig()), new ConsumerConfig(options.ConnectionConfig()) };
        foreach (var config in clients)
        {
            Assert.Equal(SecurityProtocol.SaslSsl, config.SecurityProtocol);
            Assert.Equal(SaslMechanism.Plain, config.SaslMechanism);
            Assert.Equal("test-user", config.SaslUsername);
            Assert.Equal("test-password", config.SaslPassword);
            Assert.Equal("/etc/secrets/kafka-ca.pem", config.SslCaLocation);
            Assert.True(config.EnableSslCertificateVerification);
            Assert.Equal(SslEndpointIdentificationAlgorithm.Https, config.SslEndpointIdentificationAlgorithm);
        }
    }

    [Fact]
    public void RejectsCredentialsWithoutTlsAndMissingCredentials()
    {
        Assert.Throws<InvalidOperationException>(() => new KafkaOptions { SecurityProtocol = SecurityProtocol.SaslPlaintext }.ConnectionConfig());
        Assert.Throws<InvalidOperationException>(() => new KafkaOptions { SecurityProtocol = SecurityProtocol.SaslSsl }.ConnectionConfig());
    }
}
