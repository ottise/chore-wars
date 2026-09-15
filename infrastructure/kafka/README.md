# Apache Kafka Infrastructure

Chore Wars uses Apache Kafka as an asynchronous event bus to decouple domain side-effects (like achievements, notifications, and caching invalidation).

## Docker Setup (KRaft Mode)
To reduce resource consumption during development, Kafka is run in **KRaft mode** (without Zookeeper) via the root `docker-compose.yml`.
- **Image**: `confluentinc/cp-kafka:7.4.0`
- **Port**: `9092` (internal), `29092` (external/host).
- **Setup**: A custom entrypoint script initializes the cluster ID and formats the storage before starting Kafka.

## Topics
Topics are strictly defined in `src/Infrastructure/Messaging/Kafka/KafkaTopics.cs`.
Current topics include:
- `chore.completed`
- `chore.overdue`
- `bounty.created`
- `season.ended`

## Consumers
Consumers are implemented as `.NET BackgroundService` classes (e.g. `ChoreCompletedConsumer`). They listen to their respective topics and use an `IServiceScopeFactory` to resolve Scoped Application services (like `AchievementCheckService`) to process the event.
