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

public class ChoreBountyRepository : IChoreBountyRepository
{
    private readonly AppDbContext _context;

    public ChoreBountyRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ChoreBounty?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreBounties.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<ChoreBounty?> GetByOccurrenceIdAsync(Guid occurrenceId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreBounties
            .FirstOrDefaultAsync(b => b.ChoreOccurrenceId == occurrenceId && b.Status != BountyStatus.CANCELLED, cancellationToken);
    }

    public async Task<IEnumerable<ChoreBounty>> GetActiveBountiesByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreBounties
            .Include(b => b.ChoreOccurrence)
            .ThenInclude(o => o.Chore)
            .Include(b => b.PostedByUser)
            .Where(b => b.ChoreOccurrence.Chore.HouseId == houseId && b.Status == BountyStatus.OPEN)
            .OrderBy(b => b.ExpiresAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<ChoreBounty>> GetExpiredEligibleBountiesAsync(DateTime now, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreBounties
            .Include(b => b.ChoreOccurrence)
            .ThenInclude(o => o.Chore)
            .Where(b => (b.Status == BountyStatus.OPEN || b.Status == BountyStatus.CLAIMED) && b.ExpiresAt < now)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(ChoreBounty bounty, CancellationToken cancellationToken = default)
    {
        await _context.ChoreBounties.AddAsync(bounty, cancellationToken);
    }

    public void Update(ChoreBounty bounty)
    {
        _context.ChoreBounties.Update(bounty);
    }
}
