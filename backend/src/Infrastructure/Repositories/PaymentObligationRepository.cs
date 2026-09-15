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

public class PaymentObligationRepository : IPaymentObligationRepository
{
    private readonly AppDbContext _context;

    public PaymentObligationRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<PaymentObligation?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.PaymentObligations.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<IEnumerable<PaymentObligation>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default)
    {
        return await _context.PaymentObligations
            .Where(p => p.HouseId == houseId)
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<PaymentObligation>> GetPendingObligationsByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.PaymentObligations
            .Where(p => p.DebtorUserId == userId && p.Status == Domain.Enums.PaymentObligationStatus.PENDING)
            .OrderBy(p => p.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(PaymentObligation obligation, CancellationToken cancellationToken = default)
    {
        await _context.PaymentObligations.AddAsync(obligation, cancellationToken);
    }

    public void Update(PaymentObligation obligation)
    {
        _context.PaymentObligations.Update(obligation);
    }
}
