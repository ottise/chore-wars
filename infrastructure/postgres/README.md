# PostgreSQL Infrastructure

Chore Wars uses PostgreSQL as its primary relational database.

## Docker Setup
PostgreSQL is configured in the root `docker-compose.yml`.
- **Image**: `postgres:15-alpine`
- **Port**: `5432` mapped to host `5432`
- **Volumes**: Persistent data is stored in the `postgres_data` Docker volume.

## Database Connections
The backend application connects to Postgres using Npgsql via Entity Framework Core.
- The connection string is defined in `appsettings.json` under `ConnectionStrings:DefaultConnection`.

## Migrations
Since we use Code-First Entity Framework, changes to the C# Domain entities require generating a new migration:
```bash
cd backend
dotnet ef migrations add <MigrationName> --project src/Infrastructure/Infrastructure.csproj --startup-project src/Presentation/Presentation.csproj
```
