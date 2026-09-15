using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using ChoreWars.Infrastructure.Data;

namespace ChoreWars.Infrastructure.Repositories;

public class ChoreFrequencyDayRepository : IChoreFrequencyDayRepository
{
    private readonly AppDbContext _context;

    public ChoreFrequencyDayRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<ChoreFrequencyDay>> GetByChoreIdAsync(Guid choreId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreFrequencyDays
            .Where(x => x.ChoreId == choreId)
            .ToListAsync(cancellationToken);
    }

    public async Task DeleteByChoreIdAsync(Guid choreId, CancellationToken cancellationToken = default)
    {
        var entities = await GetByChoreIdAsync(choreId, cancellationToken);
        _context.ChoreFrequencyDays.RemoveRange(entities);
    }

    public async Task AddAsync(ChoreFrequencyDay entity, CancellationToken cancellationToken = default)
    {
        await _context.ChoreFrequencyDays.AddAsync(entity, cancellationToken);
    }
}
