using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
namespace ChoreWars.Infrastructure.Concurrency;
public sealed class PostgresHouseMutationCoordinator(AppDbContext db, IUnitOfWork uow, IAfterCommitActions afterCommit, ChoreWars.Infrastructure.Diagnostics.IRuntimeProbe? probe = null) : IHouseMutationCoordinator {
    private Guid? _house;
    public async Task RunAsync(Guid houseId, Func<Task> action, CancellationToken ct = default) {
        await RunAsync(houseId, async () => { await action(); return true; }, ct);
    }
    public async Task<T> RunAsync<T>(Guid houseId, Func<Task<T>> action, CancellationToken ct = default) {
        if (_house.HasValue) {
            if (_house != houseId) throw new InvalidOperationException("A mutation cannot span households.");
            return await action();
        }
        await uow.BeginTransactionAsync(ct);
        try {
            // PostgreSQL releases this lock on commit/rollback, including process failure.
            await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({houseId.ToString()}, 0))", ct);
            db.ChangeTracker.Clear(); // ResolveHouse probes must not leave pre-lock snapshots tracked.
            _house = houseId;
            var result = await action();
            await uow.SaveChangesAsync(ct);
            if (probe != null) await probe.HitAsync("mutation.before-commit",ct);
            await uow.CommitTransactionAsync(ct);
            if (probe != null) await probe.HitAsync("mutation.after-commit",ct);
            await afterCommit.FlushAsync();
            return result;
        } catch { afterCommit.Clear(); await uow.RollbackTransactionAsync(ct); db.ChangeTracker.Clear(); throw; }
        finally { _house = null; }
    }
}
