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

public class SeasonRankingRepository : ISeasonRankingRepository
{
    private readonly AppDbContext _context;

    public SeasonRankingRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<SeasonRanking?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.SeasonRankings.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<SeasonRanking?> GetBySeasonAndUserIdAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.SeasonRankings
            .Include(r => r.User)
            .FirstOrDefaultAsync(r => r.SeasonId == seasonId && r.UserId == userId, cancellationToken);
    }

    public async Task<IEnumerable<SeasonRanking>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.SeasonRankings
            .Include(r => r.User)
            .Where(r => r.SeasonId == seasonId)
            .OrderByDescending(r => r.TotalKarma)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(SeasonRanking ranking, CancellationToken cancellationToken = default)
    {
        await _context.SeasonRankings.AddAsync(ranking, cancellationToken);
    }

    public void Update(SeasonRanking ranking)
    {
        _context.SeasonRankings.Update(ranking);
    }
}
