using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ChoreWars.Infrastructure.Repositories;

public class ActionProposalRepository : IActionProposalRepository
{
    private readonly AppDbContext _context;

    public ActionProposalRepository(AppDbContext context) => _context = context;

    public Task<ActionProposal?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        _context.ActionProposals
            .Include(x => x.Confirmations)
            .FirstOrDefaultAsync(x => x.Id == id, cancellationToken);

    public Task<ActionProposal?> GetByIdForUpdateAsync(Guid id, CancellationToken cancellationToken = default) =>
        _context.ActionProposals
            .FromSqlInterpolated($"SELECT * FROM \"ActionProposals\" WHERE \"Id\" = {id} FOR UPDATE")
            .Include(x => x.Confirmations)
            .SingleOrDefaultAsync(cancellationToken);

    public async Task<IReadOnlyList<ActionProposal>> GetActiveByRoomIdAsync(Guid roomId, DateTime now, CancellationToken cancellationToken = default) =>
        await _context.ActionProposals
            .AsNoTracking()
            .Include(x => x.Confirmations)
            .Where(x => x.RoomId == roomId &&
                ((x.Status == ProposalStatus.PENDING && (!x.ExpiresAt.HasValue || x.ExpiresAt > now)) ||
                 (x.Type == ProposalType.URGENT_EVENT && x.Status == ProposalStatus.APPROVED &&
                  x.ExpiresAt.HasValue && x.ExpiresAt > now)))
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync(cancellationToken);

    public Task AddAsync(ActionProposal proposal, CancellationToken cancellationToken = default) =>
        _context.ActionProposals.AddAsync(proposal, cancellationToken).AsTask();

    public void Update(ActionProposal proposal) => _context.ActionProposals.Update(proposal);
}
