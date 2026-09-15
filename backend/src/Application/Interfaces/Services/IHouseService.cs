using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ChoreWars.Application.DTOs.House;

namespace ChoreWars.Application.Interfaces.Services;

public interface IHouseService
{
    Task<HouseResponse> CreateHouseAsync(CreateHouseRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task JoinHouseAsync(JoinHouseRequest request, Guid userId, CancellationToken cancellationToken = default);
    Task LeaveHouseAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task KickMemberAsync(Guid houseId, Guid memberId, Guid currentUserId, CancellationToken cancellationToken = default);
    Task<IEnumerable<HouseMemberResponse>> GetMembersAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task<HouseResponse> GetHouseAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<HouseResponse>> GetUserHousesAsync(Guid userId, CancellationToken cancellationToken = default);
    Task TransferOwnershipAsync(Guid houseId, Guid newOwnerId, Guid currentUserId, CancellationToken cancellationToken = default);
}
