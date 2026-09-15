# Redis Infrastructure

Chore Wars uses Redis as an in-memory caching layer.

## Docker Setup
Redis is configured in the root `docker-compose.yml`.
- **Image**: `redis:7-alpine`
- **Port**: `6379` mapped to host `6379`
- **Volumes**: Data is not persistently stored on disk for cache. If the container restarts, cache is wiped (which is acceptable for caching purposes).

## Usage in App
The backend application connects to Redis using the `StackExchange.Redis` library.
It is primarily used for:
- Caching active `ChoreSeasons` to prevent excessive DB hits.
- Caching user permissions and roles.

The connection string is defined in `appsettings.json` under `CacheSettings:RedisConnectionString`.
