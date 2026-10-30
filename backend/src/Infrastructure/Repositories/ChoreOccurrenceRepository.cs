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

public class ChoreOccurrenceRepository : IChoreOccurrenceRepository
{
    public Task<int> CountAcceptedBountiesAsync(Guid houseId, Guid userId, CancellationToken ct = default)
        => (from episode in _context.Set<ChoreResponsibility>()
            join occurrence in _context.ChoreOccurrences on episode.OccurrenceId equals occurrence.Id
            where episode.UserId == userId && episode.Reason == "BOUNTY" && occurrence.Chore.HouseId == houseId
            select episode.Id).CountAsync(ct);
    private readonly AppDbContext _context;

    public ChoreOccurrenceRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetUnresolvedByHouseIdAsync(Guid houseId, CancellationToken ct = default)
        => await _context.ChoreOccurrences.Include(o => o.Chore).Include(o => o.AssignedUser)
            .Where(o => o.Chore.HouseId == houseId && o.Chore.Type == ChoreWars.Domain.Enums.ChoreType.NORMAL
                && o.Status != ChoreWars.Domain.Enums.ChoreOccurrenceStatus.COMPLETED && o.Status != ChoreWars.Domain.Enums.ChoreOccurrenceStatus.SKIPPED
                && (o.Status == ChoreWars.Domain.Enums.ChoreOccurrenceStatus.CRITICAL_OVERDUE || _context.ChoreBounties.Any(b => b.ChoreOccurrenceId == o.Id && b.Status == ChoreWars.Domain.Enums.BountyStatus.EXPIRED)))
            .ToListAsync(ct);

    public async Task AddResponsibilityAsync(ChoreResponsibility responsibility, CancellationToken cancellationToken = default)
        => await _context.Set<ChoreResponsibility>().AddAsync(responsibility, cancellationToken);

    public async Task<ChoreOccurrence?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences.Include(o => o.Responsibilities)
            .Include(o => o.Chore)
            .Include(o => o.AssignedUser)
            .FirstOrDefaultAsync(o => o.Id == id, cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetByAssignedUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences.Include(o => o.Responsibilities)
            .Include(o => o.Chore)
            .Include(o => o.AssignedUser)
            .Where(o => o.AssignedUserId == userId)
            .OrderBy(o => o.DueDate)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetByChoreIdAsync(Guid choreId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences.Include(o => o.Responsibilities)
            .Where(o => o.ChoreId == choreId)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences.Include(o => o.Responsibilities)
            .Include(o => o.Chore)
            .Include(o => o.AssignedUser)
            .Where(o => o.SeasonId == seasonId)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetUnassignedBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences.Include(o => o.Responsibilities)
            .Include(o => o.Chore)
            .Where(o => o.SeasonId == seasonId && o.AssignedUserId == null)
            .OrderBy(o => o.DueDate)
            .ToListAsync(cancellationToken);
    }

    public async Task<bool> HasOccurrencesForSeasonAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        return await _context.ChoreOccurrences.Include(o => o.Responsibilities)
            .AnyAsync(o => o.SeasonId == seasonId, cancellationToken);
    }

    public async Task<IEnumerable<ChoreOccurrence>> GetOverdueEligibleOccurrencesAsync(DateTime now, CancellationToken cancellationToken = default)
    {
        // Eligibility for penalty:
        // DueDate is in the past
        // Status is ASSIGNED or OVERDUE
        return await _context.ChoreOccurrences.Include(o => o.Responsibilities)
            .Include(o => o.Chore)
            .Where(o => (o.Status == ChoreOccurrenceStatus.ASSIGNED || o.Status == ChoreOccurrenceStatus.OVERDUE)
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

    public async Task DeleteBySeasonIdAsync(Guid seasonId, CancellationToken cancellationToken = default)
    {
        var season = await _context.Seasons.FindAsync(new object[] { seasonId }, cancellationToken);
        if (season?.Status != SeasonStatus.DRAFT) throw new ChoreWars.Domain.Exceptions.ConflictException("Only an unpublished draft can be regenerated.");
        var draft = _context.ChoreOccurrences.Where(o => o.SeasonId == seasonId);
        if (await draft.AnyAsync(o => o.Status != ChoreOccurrenceStatus.ASSIGNED || o.CompletedAt != null || o.EvidenceId != null || o.ProofImageUrl != null || o.PenaltyCount > 0 ||
            _context.PaymentObligations.Any(p => p.OccurrenceId == o.Id) || _context.ChoreBounties.Any(b => b.ChoreOccurrenceId == o.Id), cancellationToken))
            throw new ChoreWars.Domain.Exceptions.ConflictException("This draft contains recorded work or financial history and cannot be regenerated.");
        // These are unpublished draft assignments. Keep the redistribution audit and all published work.
        var ids = draft.Select(o => o.Id);
        await _context.Set<ChoreResponsibility>().Where(r => ids.Contains(r.OccurrenceId)).ExecuteDeleteAsync(cancellationToken);
        await draft.ExecuteDeleteAsync(cancellationToken);
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
