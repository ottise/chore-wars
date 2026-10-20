namespace ChoreWars.Infrastructure.Messaging.Kafka;

public class KafkaOptions
{
    public string BootstrapServers { get; set; } = string.Empty;
    public string ConsumerGroupId { get; set; } = "chore-wars-group";
    public string TopicPrefix { get; set; } = "";
    public int SessionTimeoutMs { get; set; } = 45000;
}
