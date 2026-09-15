# Deployment Guide

Chore Wars utilizes Docker and Docker Compose to streamline deployment.

## Production Setup

In a production environment, the following changes are required compared to the local development environment:

1. **Kafka (KRaft Mode)**: While suitable for development, for production, you should run Kafka across multiple nodes to ensure high availability, or use a managed service like Confluent Cloud.
2. **PostgreSQL**: Ensure volume mapping points to a highly resilient storage layer.
3. **Reverse Proxy**: Place an API Gateway or Reverse Proxy (e.g., NGINX, Traefik) in front of the .NET Web API to handle SSL termination.

## Environment Variables

The backend relies on the following key environment variables (to be set in `docker-compose.yml` or your orchestrator):

- `ConnectionStrings__DefaultConnection`: The PostgreSQL connection string.
- `CacheSettings__RedisConnectionString`: The Redis connection string.
- `KafkaSettings__BootstrapServers`: Comma-separated list of Kafka brokers (e.g., `kafka:29092`).
- `JwtSettings__Secret`: A strong, random 256-bit key used for signing JWTs.
- `JwtSettings__Issuer` and `JwtSettings__Audience`.

## Running with Docker Compose

A single `docker-compose.yml` file is provided at the root of the project.

### 1. Build and Start
```bash
docker compose up -d --build
```
This will build the .NET API image and start Postgres, Redis, and Kafka.

### 2. Migrations
By default, Entity Framework migrations must be run manually or triggered during CI/CD. The API does *not* auto-migrate on startup in production to avoid race conditions.
```bash
dotnet ef database update
```

### 3. Monitoring
You can monitor the logs of all containers using:
```bash
docker compose logs -f
```
Or check the health status:
```bash
docker compose ps
```
