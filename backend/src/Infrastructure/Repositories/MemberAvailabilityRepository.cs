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

public class MemberAvailabilityRepository : IMemberAvailabilityRepository
{
    private readonly AppDbContext _context;

    public MemberAvailabilityRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<MemberAvailability?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.MemberAvailabilities.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<MemberAvailability>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.MemberAvailabilities
            .Where(a => a.SeasonId == seasonId)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<MemberAvailability>> GetBySeasonAndUserIdAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.MemberAvailabilities
            .Where(a => a.SeasonId == seasonId && a.UserId == userId)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(MemberAvailability availability, CancellationToken cancellationToken = default)
    {
        await _context.MemberAvailabilities.AddAsync(availability, cancellationToken);
    }

    public void Update(MemberAvailability availability)
    {
        _context.MemberAvailabilities.Update(availability);
    }

    public void Delete(MemberAvailability availability)
    {
        _context.MemberAvailabilities.Remove(availability);
    }
}
