using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.Repositories;

public sealed class PushDeviceTokenRepository(AppDbContext context) : IPushDeviceTokenRepository
{
    public Task<PushDeviceToken?> GetByTokenAsync(string token, CancellationToken cancellationToken = default) =>
        context.PushDeviceTokens.FirstOrDefaultAsync(x => x.Token == token, cancellationToken);

    public async Task<IReadOnlyList<PushDeviceToken>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default) =>
        await context.PushDeviceTokens.Where(x => x.UserId == userId).ToListAsync(cancellationToken);

    public Task AddAsync(PushDeviceToken token, CancellationToken cancellationToken = default) =>
        context.PushDeviceTokens.AddAsync(token, cancellationToken).AsTask();

    public void Update(PushDeviceToken token) => context.PushDeviceTokens.Update(token);

    public async Task DeleteAsync(Guid userId, string token, CancellationToken cancellationToken = default)
    {
        var entity = await context.PushDeviceTokens.FirstOrDefaultAsync(x => x.UserId == userId && x.Token == token, cancellationToken);
        if (entity != null) context.PushDeviceTokens.Remove(entity);
    }

    public async Task DeleteByTokenAsync(string token, CancellationToken cancellationToken = default)
    {
        var entity = await context.PushDeviceTokens.FirstOrDefaultAsync(x => x.Token == token, cancellationToken);
        if (entity != null) context.PushDeviceTokens.Remove(entity);
    }
}
