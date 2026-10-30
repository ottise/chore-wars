using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace ChoreWars.Infrastructure.Workers;

/// Preserve referenced legacy uploads, including photos no one opens again
/// before a restart. Missing bytes are reported; message history stays intact.
public sealed class LegacyMediaMigrationWorker(IServiceScopeFactory scopes, ILogger<LegacyMediaMigrationWorker> logger) : BackgroundService {
    public async Task<(int Migrated, int Missing)> MigrateAsync(CancellationToken ct) {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var storage = scope.ServiceProvider.GetRequiredService<DatabaseMediaStorage>();
        var chatKeys = db.MediaAttachments.Where(m => m.AttachedAt != null || db.ChatMessages.Any(c => c.AttachmentId == m.Id)).Select(m => m.StorageKey);
        var evidenceKeys = db.ChoreEvidence.Where(e => e.AttachedAt != null || db.ChoreOccurrences.Any(o => o.EvidenceId == e.Id)).Select(e => e.StorageKey);
        var keys = await chatKeys.Union(evidenceKeys).Where(key => !db.PrivateMediaFiles.Any(f => f.StorageKey == key)).ToListAsync(ct);
        int migrated = 0, missing = 0;
        foreach (var key in keys) {
            try { await using var stream = await storage.ReadAsync(key, ct); migrated++; }
            catch (NotFoundException) { missing++; }
        }
        if (migrated > 0) logger.LogInformation("Legacy media preservation: {Migrated} files stored in database.", migrated);
        if (missing > 0) logger.LogWarning("Legacy media preservation: {Missing} files unavailable. Recovery requires the original upload or backup.", missing);
        return (migrated, missing);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken) {
        while (!stoppingToken.IsCancellationRequested) {
            try { await MigrateAsync(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception error) { logger.LogError(error, "Legacy media preservation failed; will retry."); }
            try { await Task.Delay(TimeSpan.FromHours(1), stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }
}
