using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class RewardRedemptionRepository : IRewardRedemptionRepository
{
    private readonly AppDbContext _context;

    public RewardRedemptionRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<RewardRedemption?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.RewardRedemptions.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<RewardRedemption>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.RewardRedemptions
            .Include(r => r.Reward)
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.RedeemedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<RewardRedemption?> GetByRewardAndUserIdAsync(Guid rewardId, Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.RewardRedemptions
            .FirstOrDefaultAsync(r => r.RewardId == rewardId && r.UserId == userId, cancellationToken);
    }

    public async Task AddAsync(RewardRedemption redemption, CancellationToken cancellationToken = default)
    {
        await _context.RewardRedemptions.AddAsync(redemption, cancellationToken);
    }

    public void Update(RewardRedemption redemption)
    {
        _context.RewardRedemptions.Update(redemption);
    }
}
