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

public class ChoreOccurrenceRepository : IChoreOccurrenceRepository
{
    private readonly AppDbContext _context;

    public ChoreOccurrenceRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ChoreOccurrence?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences
            .Include(o => o.Chore)
            .Include(o => o.AssignedUser)
            .FirstOrDefaultAsync(o => o.Id == id, cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetByAssignedUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences
            .Include(o => o.Chore)
            .Include(o => o.AssignedUser)
            .Where(o => o.AssignedUserId == userId)
            .OrderBy(o => o.DueDate)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetByChoreIdAsync(Guid choreId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences
            .Where(o => o.ChoreId == choreId)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetUnassignedBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences
            .Include(o => o.Chore)
            .Where(o => o.Chore.SeasonId == seasonId && o.AssignedUserId == null)
            .OrderBy(o => o.DueDate)
            .ToListAsync(cancellationToken);
    }

    public async Task<bool> HasOccurrencesForSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences
            .AnyAsync(o => o.Chore.SeasonId == seasonId, cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetOverdueEligibleOccurrencesAsync(DateTime now, CancellationToken cancellationToken = default)
    {
        // Eligibility for penalty:
        // DueDate is in the past
        // Status is ASSIGNED or OVERDUE
        return await _context.ChoreOccurrences
            .Include(o => o.Chore)
            .Where(o => (o.Status == ChoreWars.Domain.Enums.ChoreOccurrenceStatus.ASSIGNED || o.Status == ChoreWars.Domain.Enums.ChoreOccurrenceStatus.OVERDUE)
                     && o.DueDate < now)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(ChoreOccurrence occurrence, CancellationToken cancellationToken = default)
    {
        await _context.ChoreOccurrences.AddAsync(occurrence, cancellationToken);
    }

    public async Task AddRangeAsync(IEnumerable<ChoreOccurrence> occurrences, CancellationToken cancellationToken = default)
    {
        await _context.ChoreOccurrences.AddRangeAsync(occurrences, cancellationToken);
    }

    public void Update(ChoreOccurrence occurrence)
    {
        _context.ChoreOccurrences.Update(occurrence);
    }

    public void Delete(ChoreOccurrence occurrence)
    {
        _context.ChoreOccurrences.Remove(occurrence);
    }
}
