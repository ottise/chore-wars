using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.Bounty;

namespace ChoreWars.Application.Interfaces.Services;

public interface IBountyService
{
    Task<BountyResponse> CreateBountyAsync(Guid houseId, CreateBountyRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task AcceptBountyAsync(Guid bountyId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<BountyResponse>> GetBountiesAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task SettlePaymentAsync(Guid paymentId, Guid userId, CancellationToken cancellationToken = default);
}
