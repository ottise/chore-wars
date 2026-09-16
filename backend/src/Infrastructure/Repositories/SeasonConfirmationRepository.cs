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

public class SeasonConfirmationRepository : ISeasonConfirmationRepository
{
    private readonly AppDbContext _context;

    public SeasonConfirmationRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<SeasonConfirmation?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.SeasonConfirmations.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<SeasonConfirmation>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.SeasonConfirmations
            .Where(c => c.SeasonId == seasonId)
            .ToListAsync(cancellationToken);
    }

    public async Task<SeasonConfirmation?> GetBySeasonAndUserIdAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.SeasonConfirmations
            .FirstOrDefaultAsync(c => c.SeasonId == seasonId && c.UserId == userId, cancellationToken);
    }

    public async Task AddAsync(SeasonConfirmation confirmation, CancellationToken cancellationToken = default)
    {
        await _context.SeasonConfirmations.AddAsync(confirmation, cancellationToken);
    }

    public async Task DeleteBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        await _context.SeasonConfirmations
            .Where(c => c.SeasonId == seasonId)
            .ExecuteDeleteAsync(cancellationToken);
    }

    public void Update(SeasonConfirmation confirmation)
    {
        _context.SeasonConfirmations.Update(confirmation);
    }

    public void Delete(SeasonConfirmation confirmation)
    {
        _context.SeasonConfirmations.Remove(confirmation);
    }
}
