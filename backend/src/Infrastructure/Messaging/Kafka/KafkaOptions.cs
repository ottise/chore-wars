namespace ChoreWars.Infrastructure.Messaging.Kafka;

public class KafkaOptions
{
    public string BootstrapServers { get; set; } = string.Empty;
    public string ConsumerGroupId { get; set; } = "chore-wars-group";
}
