using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class RewardRepository : IRewardRepository
{
    private readonly AppDbContext _context;

    public RewardRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Reward?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Rewards.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<Reward>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.Rewards
            .Where(r => r.SeasonId == seasonId)
            .ToListAsync(cancellationToken);
    }

    public async Task<Reward?> GetChorePassRewardAsync(CancellationToken cancellationToken = default)
    {
        return await _context.Rewards
            .FirstOrDefaultAsync(r => r.Type == RewardType.CHORE_PASS, cancellationToken);
    }

    public async Task AddAsync(Reward reward, CancellationToken cancellationToken = default)
    {
        await _context.Rewards.AddAsync(reward, cancellationToken);
    }

    public void Update(Reward reward)
    {
        _context.Rewards.Update(reward);
    }

    public void Delete(Reward reward)
    {
        _context.Rewards.Remove(reward);
    }
}
