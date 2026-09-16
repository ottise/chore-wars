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

public class KarmaTransactionRepository : IKarmaTransactionRepository
{
    private readonly AppDbContext _context;

    public KarmaTransactionRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<KarmaTransaction?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.KarmaTransactions.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<KarmaTransaction>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.KarmaTransactions
            .Where(t => t.UserId == userId)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<KarmaTransaction>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.KarmaTransactions
            .Where(k => k.SeasonId == seasonId)
            .OrderByDescending(k => k.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<KarmaTransaction>> GetByReferenceIdAndTypeAsync(Guid referenceId, KarmaTransactionType type, CancellationToken cancellationToken = default)
    {
        return await _context.KarmaTransactions
            .Where(k => k.ReferenceId == referenceId && k.Type == type)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(KarmaTransaction transaction, CancellationToken cancellationToken = default)
    {
        await _context.KarmaTransactions.AddAsync(transaction, cancellationToken);
    }
}
