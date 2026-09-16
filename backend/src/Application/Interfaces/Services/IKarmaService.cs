using System;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Application.Interfaces.Services;

public interface IKarmaService
{
    Task AddKarmaTransactionAsync(Guid houseId, Guid seasonId, Guid userId, int amount, KarmaTransactionType type, Guid? referenceId = null, CancellationToken cancellationToken = default);
}
