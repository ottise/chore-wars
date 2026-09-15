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

public class ChoreRepository : IChoreRepository
{
    private readonly AppDbContext _context;

    public ChoreRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Chore?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Chores.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<Chore>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.Chores
            .Where(c => c.HouseId == houseId)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<Chore>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.Chores
            .Where(c => c.SeasonId == seasonId)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(Chore chore, CancellationToken cancellationToken = default)
    {
        await _context.Chores.AddAsync(chore, cancellationToken);
    }

    public void Update(Chore chore)
    {
        _context.Chores.Update(chore);
    }

    public void Delete(Chore chore)
    {
        _context.Chores.Remove(chore);
    }
}
