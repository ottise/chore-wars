using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Domain.Common.Constants;

namespace ChoreWars.Application.Services;

public class HouseService : IHouseService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;

    public HouseService(IUnitOfWork unitOfWork, IMapper mapper)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
    }

    public async Task<HouseResponse> CreateHouseAsync(CreateHouseRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await _unitOfWork.Users.GetByIdAsync(userId, cancellationToken);
        if (user == null)
            throw new NotFoundException(nameof(User), userId);

        var house = new House
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            InviteCode = await GenerateUniqueInviteCodeAsync(cancellationToken),
            CreatedAt = DateTime.UtcNow
        };

        var member = new HouseMember
        {
            Id = Guid.NewGuid(),
            HouseId = house.Id,
            UserId = userId,
            Role = HouseRole.OWNER,
            Status = HouseMemberStatus.ACTIVE,
            JoinedAt = DateTime.UtcNow
        };

        var room = new ChatRoom
        {
            Id = Guid.NewGuid(),
            HouseId = house.Id,
            Name = $"{request.Name} Chat",
            CreatedAt = DateTime.UtcNow
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Houses.AddAsync(house, cancellationToken);
            await _unitOfWork.HouseMembers.AddAsync(member, cancellationToken);
            await _unitOfWork.Chats.AddRoomAsync(room, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<HouseResponse>(house);
    }

    public async Task JoinHouseAsync(JoinHouseRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var house = await _unitOfWork.Houses.GetByInviteCodeAsync(request.InviteCode, cancellationToken);
        if (house == null)
            throw new NotFoundException("House with provided invite code not found.");

        var existingMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(house.Id, userId, cancellationToken);
        if (existingMember != null)
            throw new ConflictException("User is already a member of this house.");

        var member = new HouseMember
        {
            Id = Guid.NewGuid(),
            HouseId = house.Id,
            UserId = userId,
            Role = HouseRole.MEMBER,
            Status = HouseMemberStatus.ACTIVE,
            JoinedAt = DateTime.UtcNow
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.HouseMembers.AddAsync(member, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task LeaveHouseAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null)
            throw new NotFoundException(nameof(HouseMember), userId);

        if (member.Role == HouseRole.OWNER)
        {
            // Simplified logic: An owner cannot leave unless they transfer ownership or disband.
            throw new ConflictException("Owner cannot leave the house.");
        }

        var userOccurrences = await _unitOfWork.ChoreOccurrences.GetByAssignedUserIdAsync(userId, cancellationToken);
        var activeHouseOccurrences = userOccurrences.Where(o => o.Chore?.HouseId == houseId && 
            (o.Status == ChoreOccurrenceStatus.ASSIGNED || o.Status == ChoreOccurrenceStatus.OVERDUE)).ToList();

        if (activeHouseOccurrences.Any())
        {
            throw new ConflictException("Cannot leave house with active chore occurrences. Please complete or reassign them.");
        }

        member.Status = HouseMemberStatus.LEFT;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.HouseMembers.Update(member);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task KickMemberAsync(Guid houseId, Guid memberId, Guid currentUserId, CancellationToken cancellationToken = default)
    {
        var currentMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, currentUserId, cancellationToken);
        if (currentMember == null || currentMember.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can kick members.");

        var memberToKick = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, memberId, cancellationToken);
        if (memberToKick == null)
            throw new NotFoundException(nameof(HouseMember), memberId);

        if (memberToKick.Role == HouseRole.OWNER)
            throw new ConflictException("Cannot kick the owner.");

        memberToKick.Status = HouseMemberStatus.BANNED;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.HouseMembers.Update(memberToKick);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<IEnumerable<HouseMemberResponse>> GetMembersAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var currentMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (currentMember == null || currentMember.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        var members = await _unitOfWork.HouseMembers.GetByHouseIdAsync(houseId, cancellationToken);
        return _mapper.Map<IEnumerable<HouseMemberResponse>>(members);
    }

    private async Task<string> GenerateUniqueInviteCodeAsync(CancellationToken cancellationToken)
    {
        const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        while (true)
        {
            var charsArray = new char[HouseConstants.InviteCodeLength];
            var randomBytes = new byte[HouseConstants.InviteCodeLength];
            System.Security.Cryptography.RandomNumberGenerator.Fill(randomBytes);
            
            for (int i = 0; i < charsArray.Length; i++)
            {
                charsArray[i] = chars[randomBytes[i] % chars.Length];
            }
            var code = new string(charsArray);
            
            var existingHouse = await _unitOfWork.Houses.GetByInviteCodeAsync(code, cancellationToken);
            if (existingHouse == null)
            {
                return code;
            }
        }
    }

    public async Task<HouseResponse> GetHouseAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        var house = await _unitOfWork.Houses.GetByIdAsync(houseId, cancellationToken);
        if (house == null)
            throw new NotFoundException(nameof(House), houseId);

        return _mapper.Map<HouseResponse>(house);
    }

    public async Task<IEnumerable<HouseResponse>> GetUserHousesAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var members = await _unitOfWork.HouseMembers.GetByUserIdAsync(userId, cancellationToken);
        var activeHouseIds = members.Where(m => m.Status == HouseMemberStatus.ACTIVE).Select(m => m.HouseId).ToList();

        var houses = new List<House>();
        foreach (var houseId in activeHouseIds)
        {
            var house = await _unitOfWork.Houses.GetByIdAsync(houseId, cancellationToken);
            if (house != null)
                houses.Add(house);
        }

        return _mapper.Map<IEnumerable<HouseResponse>>(houses);
    }

    public async Task TransferOwnershipAsync(Guid houseId, Guid newOwnerId, Guid currentUserId, CancellationToken cancellationToken = default)
    {
        var currentMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, currentUserId, cancellationToken);
        if (currentMember == null || currentMember.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can transfer ownership.");

        var newOwnerMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, newOwnerId, cancellationToken);
        if (newOwnerMember == null || newOwnerMember.Status != HouseMemberStatus.ACTIVE)
            throw new ConflictException("New owner must be an active member of the house.");

        currentMember.Role = HouseRole.MEMBER;
        newOwnerMember.Role = HouseRole.OWNER;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.HouseMembers.Update(currentMember);
            _unitOfWork.HouseMembers.Update(newOwnerMember);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task SetMemberPreferencesAsync(Guid houseId, SetMemberPreferencesRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        var existingPrefs = await _unitOfWork.MemberPreferences.GetByUserIdAsync(userId, cancellationToken);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            // Simple approach: remove all and recreate
            foreach (var pref in existingPrefs)
            {
                var chore = await _unitOfWork.Chores.GetByIdAsync(pref.ChoreId, cancellationToken);
                if (chore != null && chore.HouseId == houseId)
                {
                    _unitOfWork.MemberPreferences.Delete(pref);
                }
            }

            foreach (var prefDto in request.Preferences)
            {
                var chore = await _unitOfWork.Chores.GetByIdAsync(prefDto.ChoreId, cancellationToken);
                if (chore == null || chore.HouseId != houseId) continue;

                var pref = new MemberPreference
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    ChoreId = prefDto.ChoreId,
                    Type = prefDto.Type
                };
                await _unitOfWork.MemberPreferences.AddAsync(pref, cancellationToken);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<IEnumerable<MemberPreferenceResponse>> GetMemberPreferencesAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        var prefs = await _unitOfWork.MemberPreferences.GetByUserIdAsync(userId, cancellationToken);
        var response = new List<MemberPreferenceResponse>();

        foreach (var pref in prefs)
        {
            var chore = await _unitOfWork.Chores.GetByIdAsync(pref.ChoreId, cancellationToken);
            if (chore != null && chore.HouseId == houseId)
            {
                response.Add(new MemberPreferenceResponse
                {
                    ChoreId = pref.ChoreId,
                    ChoreName = chore.Name,
                    Type = pref.Type
                });
            }
        }
        return response;
    }

    public async Task SetMemberConstraintAsync(Guid houseId, SetMemberConstraintRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        var existing = await _unitOfWork.MemberConstraints.GetByUserAndHouseIdAsync(userId, houseId, cancellationToken);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            if (existing != null)
            {
                existing.MaxChoresPerWeek = request.MaxChoresPerWeek;
                existing.MaxEffortMinutesPerDay = request.MaxEffortMinutesPerDay;
                _unitOfWork.MemberConstraints.Update(existing);
            }
            else
            {
                var constraint = new MemberConstraint
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    HouseId = houseId,
                    MaxChoresPerWeek = request.MaxChoresPerWeek,
                    MaxEffortMinutesPerDay = request.MaxEffortMinutesPerDay
                };
                await _unitOfWork.MemberConstraints.AddAsync(constraint, cancellationToken);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task<MemberConstraintResponse> GetMemberConstraintAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        var constraint = await _unitOfWork.MemberConstraints.GetByUserAndHouseIdAsync(userId, houseId, cancellationToken);
        if (constraint == null)
        {
            return new MemberConstraintResponse
            {
                MaxChoresPerWeek = ChoreWars.Domain.Common.Constants.AIAllocationConstants.DefaultMaxChoresPerWeek,
                MaxEffortMinutesPerDay = ChoreWars.Domain.Common.Constants.AIAllocationConstants.DefaultMaxEffortMinutesPerDay
            };
        }

        return new MemberConstraintResponse
        {
            MaxChoresPerWeek = constraint.MaxChoresPerWeek,
            MaxEffortMinutesPerDay = constraint.MaxEffortMinutesPerDay
        };
    }
}
