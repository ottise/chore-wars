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

public class ChoreSeasonRepository : IChoreSeasonRepository
{
    private readonly AppDbContext _context;

    public ChoreSeasonRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ChoreSeason?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Seasons.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<ChoreSeason>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.Seasons
            .Where(s => s.HouseId == houseId)
            .OrderByDescending(s => s.StartDate)
            .ToListAsync(cancellationToken);
    }

    public async Task<ChoreSeason?> GetActiveSeasonByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.Seasons
            .FirstOrDefaultAsync(s => s.HouseId == houseId && s.Status == SeasonStatus.ACTIVE, cancellationToken);
    }

    public async Task<IEnumerable<ChoreSeason>> GetActiveSeasonsAsync(DateTime now, CancellationToken cancellationToken = default)
    {
        return await _context.Seasons
            .Where(s => s.Status == SeasonStatus.ACTIVE)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(ChoreSeason season, CancellationToken cancellationToken = default)
    {
        await _context.Seasons.AddAsync(season, cancellationToken);
    }

    public void Update(ChoreSeason season)
    {
        _context.Seasons.Update(season);
    }
}
