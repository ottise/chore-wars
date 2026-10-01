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

public class MemberPreferenceRepository : IMemberPreferenceRepository
{
    private readonly AppDbContext _context;

    public MemberPreferenceRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<MemberPreference>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.MemberPreferences
            .Where(p => p.UserId == userId)
            .ToListAsync(cancellationToken);
    }

    public async Task<MemberPreference?> GetByUserAndChoreIdAsync(Guid userId, Guid choreId, CancellationToken cancellationToken = default)
    {
        return await _context.MemberPreferences
            .FirstOrDefaultAsync(p => p.UserId == userId && p.ChoreId == choreId, cancellationToken);
    }

    public async Task AddAsync(MemberPreference preference, CancellationToken cancellationToken = default)
    {
        await _context.MemberPreferences.AddAsync(preference, cancellationToken);
    }

    public void Delete(MemberPreference preference)
    {
        _context.MemberPreferences.Remove(preference);
    }
}
