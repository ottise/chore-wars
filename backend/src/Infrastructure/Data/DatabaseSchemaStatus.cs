using System.Data;
using ChoreWars.Application.DTOs.Deployment;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Infrastructure.Data;

public sealed class DatabaseSchemaStatus(AppDbContext db, ILogger<DatabaseSchemaStatus> log) : IDatabaseSchemaStatus
{
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(2);

    public async Task<DatabaseSchemaStatusResponse> CheckAsync(CancellationToken ct = default)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(Timeout);
        var token = timeout.Token;
        var connection = db.Database.GetDbConnection();
        var close = connection.State != ConnectionState.Open;
        try
        {
            if (close) await connection.OpenAsync(token);
            var pending = (await db.Database.GetPendingMigrationsAsync(token)).ToArray();
            await using var command = connection.CreateCommand();
            command.CommandTimeout = (int)Timeout.TotalSeconds;
            command.CommandText = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'";
            var existing = new HashSet<string>(StringComparer.Ordinal);
            await using (var reader = await command.ExecuteReaderAsync(token))
                while (await reader.ReadAsync(token)) existing.Add(reader.GetString(0));
            var expected = db.Model.GetEntityTypes().Select(x => x.GetTableName()).Where(x => x != null).Distinct().Cast<string>();
            var missing = expected.Where(x => !existing.Contains(x)).Order().ToArray();
            var ready = pending.Length == 0 && missing.Length == 0;
            return new(true, ready, ready ? "schema_ready" : "schema_incomplete", pending, missing);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception error)
        {
            log.LogWarning("Schema probe failed ({ErrorType}).", error.GetType().Name);
            return new(false, false, "database_unavailable", [], []);
        }
        finally { if (close && connection.State != ConnectionState.Closed) await connection.CloseAsync(); }
    }
}
