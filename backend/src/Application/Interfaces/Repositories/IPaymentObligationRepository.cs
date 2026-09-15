using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Repositories;

public interface IPaymentObligationRepository
{
    Task<PaymentObligation?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<PaymentObligation>> GetByHouseIdAsync(Guid houseId, CancellationToken cancellationToken = default);
    Task<IEnumerable<PaymentObligation>> GetPendingObligationsByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(PaymentObligation obligation, CancellationToken cancellationToken = default);
    void Update(PaymentObligation obligation);
}
