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

public partial class HouseService : IHouseService
{
    private readonly IHouseMutationCoordinator? _mutations;
    private readonly TimeProvider _clock;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IHouseRealtimeAccess? _realtimeAccess;
    private readonly IMapper _mapper;
    private readonly IMembershipChoreRedistributor? _redistributor;
    private readonly INotificationService? _notifications;

    public HouseService(IUnitOfWork unitOfWork, IMapper mapper, IHouseMutationCoordinator? mutationCoordinator = null, IHouseRealtimeAccess? realtimeAccess = null, TimeProvider? clock = null, IMembershipChoreRedistributor? redistributor = null, INotificationService? notifications = null)
    {
        _clock = clock ?? TimeProvider.System;
        _mutations = mutationCoordinator; _realtimeAccess = realtimeAccess;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _redistributor = redistributor;
        _notifications = notifications;
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
            CreatedAt = _clock.GetUtcNow().UtcDateTime
        };

        var member = new HouseMember
        {
            Id = Guid.NewGuid(),
            HouseId = house.Id,
            UserId = userId,
            Role = HouseRole.OWNER,
            Status = HouseMemberStatus.ACTIVE,
            JoinedAt = _clock.GetUtcNow().UtcDateTime
        };

        var room = new ChatRoom
        {
            Id = Guid.NewGuid(),
            HouseId = house.Id,
            Name = $"{request.Name} Chat",
            CreatedAt = _clock.GetUtcNow().UtcDateTime
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Houses.AddAsync(house, cancellationToken);
            await _unitOfWork.HouseMembers.AddAsync(member, cancellationToken);
            await _unitOfWork.Chats.AddRoomAsync(room, cancellationToken);
            foreach (var achievement in AchievementDefaults.ForHouse(house.Id))
                await _unitOfWork.Achievements.AddAsync(achievement, cancellationToken);
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

    public async Task<List<ChoreWars.Application.DTOs.Season.RedistributionResult>> JoinHouseAsync(JoinHouseRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) return await JoinHouseCoreAsync(request, userId, cancellationToken);
        var context = await _unitOfWork.Houses.GetByInviteCodeAsync(request.InviteCode, cancellationToken) ?? throw new NotFoundException("Invitation not found.");
        return await _mutations.RunAsync(context.Id, () => JoinHouseCoreAsync(request, userId, cancellationToken), cancellationToken);
    }

    private async Task<List<ChoreWars.Application.DTOs.Season.RedistributionResult>> JoinHouseCoreAsync(JoinHouseRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var house = await _unitOfWork.Houses.GetByInviteCodeAsync(request.InviteCode, cancellationToken);
        if (house == null)
            throw new NotFoundException("House with provided invite code not found.");

        if (house.IsArchived) throw new ConflictException("This household has been archived.");
        var existingMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(house.Id, userId, cancellationToken);
        if (existingMember?.Status == HouseMemberStatus.BANNED) throw new ForbiddenException("Banned members cannot rejoin by invitation.");
        if (existingMember?.Status == HouseMemberStatus.ACTIVE) throw new ConflictException("Already a member.");
        var activeMembers = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(house.Id, cancellationToken)).Count(m => m.Status == HouseMemberStatus.ACTIVE);
        if (activeMembers >= ChoreWars.Domain.Common.Constants.HouseConstants.MaxMembersPerHouse) throw new ConflictException("A household supports at most six active members.");

        var member = existingMember ?? new HouseMember
        {
            Id = Guid.NewGuid(),
            HouseId = house.Id,
            UserId = userId,
            Role = HouseRole.MEMBER,
            Status = HouseMemberStatus.ACTIVE,
            JoinedAt = _clock.GetUtcNow().UtcDateTime
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            member.Status = HouseMemberStatus.ACTIVE;
            member.JoinedAt = _clock.GetUtcNow().UtcDateTime;
            if (existingMember == null) await _unitOfWork.HouseMembers.AddAsync(member, cancellationToken);
            else _unitOfWork.HouseMembers.Update(member);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            var result = _redistributor != null ? await _redistributor.RedistributeAsync(house.Id, userId, cancellationToken) : new List<ChoreWars.Application.DTOs.Season.RedistributionResult>();
            if (_notifications != null)
            {
                var recipients = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(house.Id, cancellationToken)).Where(m => m.Status == HouseMemberStatus.ACTIVE && m.UserId != userId);
                foreach (var recipient in recipients) await _notifications.CreateNotificationAsync(recipient.UserId, house.Id, "New household member", "A member joined. Review your household schedule for updated assignments.", "MEMBER_JOINED", "HOUSE", house.Id, cancellationToken);
            }
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
            return result;
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task LeaveHouseAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await LeaveHouseCoreAsync(houseId, userId, cancellationToken); return; }

        await _mutations.RunAsync(houseId, () => LeaveHouseCoreAsync(houseId, userId, cancellationToken), cancellationToken);
    }

    private async Task LeaveHouseCoreAsync(Guid houseId, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new NotFoundException(nameof(HouseMember), userId);
        var house = await _unitOfWork.Houses.GetByIdAsync(houseId, cancellationToken)
            ?? throw new NotFoundException("Household not found.");
        var members = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(houseId, cancellationToken))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE && m.UserId != userId)
            .OrderBy(m => m.JoinedAt)
            .ThenBy(m => m.UserId)
            .ToList();
        var assigned = (await _unitOfWork.ChoreOccurrences.GetByAssignedUserIdAsync(userId, cancellationToken))
            .Where(o => o.Chore?.HouseId == houseId && o.Status is ChoreOccurrenceStatus.ASSIGNED or ChoreOccurrenceStatus.OVERDUE or ChoreOccurrenceStatus.CRITICAL_OVERDUE)
            .ToList();
        var season = await _unitOfWork.Seasons.GetCurrentSeasonByHouseIdAsync(houseId, cancellationToken);
        var now = _clock.GetUtcNow().UtcDateTime;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            if (season?.Status == SeasonStatus.REVIEWING)
            {
                season.Status = SeasonStatus.DRAFT;
                season.ScheduleRevision++;
                _unitOfWork.Seasons.Update(season);
                await _unitOfWork.SeasonConfirmations.DeleteBySeasonIdAsync(season.Id, cancellationToken);
            }

            await ReassignOpenOccurrencesAsync(assigned, members, now, cancellationToken);

            if (member.Role == HouseRole.OWNER)
            {
                if (members.Count > 0)
                {
                    member.Role = HouseRole.MEMBER;
                    members[0].Role = HouseRole.OWNER;
                    _unitOfWork.HouseMembers.Update(members[0]);
                }
                else
                {
                    house.IsArchived = true;
                    house.InviteVersion++;
                    _unitOfWork.Houses.Update(house);
                    foreach (var archivedSeason in await _unitOfWork.Seasons.GetByHouseIdAsync(houseId, cancellationToken))
                    {
                        if (archivedSeason.Status is SeasonStatus.COMPLETED or SeasonStatus.CANCELLED) continue;
                        archivedSeason.Status = SeasonStatus.CANCELLED;
                        archivedSeason.ScheduleRevision++;
                        _unitOfWork.Seasons.Update(archivedSeason);
                        await _unitOfWork.SeasonConfirmations.DeleteBySeasonIdAsync(archivedSeason.Id, cancellationToken);
                    }
                }
            }

            member.Status = HouseMemberStatus.LEFT;
            _unitOfWork.HouseMembers.Update(member);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
        await RevokeRoomAsync(houseId, userId, cancellationToken);
    }

    private async Task ReassignOpenOccurrencesAsync(
        List<ChoreOccurrence> occurrences,
        IReadOnlyCollection<HouseMember> members,
        DateTime now,
        CancellationToken cancellationToken)
    {
        if (occurrences.Count == 0 || members.Count == 0) return;
        var loads = new Dictionary<Guid, int>();
        foreach (var seasonId in occurrences.Select(o => o.SeasonId).Distinct())
        {
            var seasonOccurrences = await _unitOfWork.ChoreOccurrences.GetBySeasonIdAsync(seasonId, cancellationToken);
            foreach (var group in seasonOccurrences
                .Where(o => o.AssignedUserId.HasValue && o.Status is not (ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED))
                .GroupBy(o => o.AssignedUserId!.Value))
                loads[group.Key] = group.Sum(o => Math.Max(1, o.SnapshotKarma));
        }

        foreach (var occurrence in occurrences.OrderBy(o => o.DueDate))
        {
            var recipient = members.OrderBy(m => loads.GetValueOrDefault(m.UserId))
                .ThenBy(m => m.JoinedAt).ThenBy(m => m.UserId).First();
            var previous = await ChoreResponsibilityService.EnsureAsync(_unitOfWork, occurrence, now, cancellationToken);
            previous.EndedAt = now;
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.ChoreOccurrences.AddResponsibilityAsync(new ChoreResponsibility
            {
                Id = Guid.NewGuid(),
                OccurrenceId = occurrence.Id,
                UserId = recipient.UserId,
                Reason = "MEMBER_LEFT",
                StartedAt = now,
                Deadline = occurrence.DueDate,
                PenaltiesApplied = occurrence.PenaltyCount
            }, cancellationToken);
            occurrence.AssignedUserId = recipient.UserId;
            occurrence.PlannedStartAt = null;
            _unitOfWork.ChoreOccurrences.Update(occurrence);
            loads[recipient.UserId] = loads.GetValueOrDefault(recipient.UserId) + Math.Max(1, occurrence.SnapshotKarma);
        }
    }

    public async Task KickMemberAsync(Guid houseId, Guid memberId, Guid currentUserId, CancellationToken cancellationToken = default)
    {
        if (_mutations == null) { await KickMemberCoreAsync(houseId, memberId, currentUserId, cancellationToken); return; }

        await _mutations.RunAsync(houseId, () => KickMemberCoreAsync(houseId, memberId, currentUserId, cancellationToken), cancellationToken);
    }

    private async Task KickMemberCoreAsync(Guid houseId, Guid memberId, Guid currentUserId, CancellationToken cancellationToken = default)
    {
        var currentMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, currentUserId, cancellationToken);
        if (currentMember == null || currentMember.Status != HouseMemberStatus.ACTIVE || currentMember.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can kick members.");

        var memberToKick = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, memberId, cancellationToken);
        if (memberToKick == null || memberToKick.Status != HouseMemberStatus.ACTIVE)
            throw new NotFoundException(nameof(HouseMember), memberId);

        if (memberToKick.Role == HouseRole.OWNER)
            throw new ConflictException("Cannot kick the owner.");

        var assigned = await _unitOfWork.ChoreOccurrences.GetByAssignedUserIdAsync(memberId, cancellationToken);
        var activeHouseOccurrences = assigned.Where(o => o.Chore?.HouseId == houseId &&
            o.Status is ChoreOccurrenceStatus.ASSIGNED or ChoreOccurrenceStatus.OVERDUE or ChoreOccurrenceStatus.CRITICAL_OVERDUE).ToList();
        var remainingMembers = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(houseId, cancellationToken))
            .Where(m => m.Status == HouseMemberStatus.ACTIVE && m.UserId != memberId)
            .OrderBy(m => m.JoinedAt).ThenBy(m => m.UserId).ToList();
        var now = _clock.GetUtcNow().UtcDateTime;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await InvalidateReviewAsync(houseId, cancellationToken);
            await ReassignOpenOccurrencesAsync(activeHouseOccurrences, remainingMembers, now, cancellationToken);
            memberToKick.Status = HouseMemberStatus.BANNED;
            _unitOfWork.HouseMembers.Update(memberToKick);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
        await RevokeRoomAsync(houseId, memberId, cancellationToken);
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
        if (house.IsArchived)
            throw new NotFoundException(nameof(House), houseId);

        var response = _mapper.Map<HouseResponse>(house);
        response.CurrentUserRole = member.Role.ToString();
        return response;
    }

    public async Task<IEnumerable<HouseResponse>> GetUserHousesAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var members = await _unitOfWork.HouseMembers.GetByUserIdAsync(userId, cancellationToken);
        var activeHouseIds = members.Where(m => m.Status == HouseMemberStatus.ACTIVE).Select(m => m.HouseId).ToList();

        var houses = new List<House>();
        foreach (var houseId in activeHouseIds)
        {
            var house = await _unitOfWork.Houses.GetByIdAsync(houseId, cancellationToken);
            if (house != null && !house.IsArchived)
                houses.Add(house);
        }

        var responseList = new List<HouseResponse>();
        foreach (var house in houses)
        {
            var response = _mapper.Map<HouseResponse>(house);
            var member = members.First(m => m.HouseId == house.Id);
            response.CurrentUserRole = member.Role.ToString();
            responseList.Add(response);
        }

        return responseList;
    }

    public async Task TransferOwnershipAsync(Guid houseId, Guid newOwnerId, Guid currentUserId, CancellationToken cancellationToken = default)
    {
        if (_mutations != null) await _mutations.RunAsync(houseId, () => TransferOwnershipCoreAsync(houseId, newOwnerId, currentUserId, cancellationToken), cancellationToken);
        else await TransferOwnershipCoreAsync(houseId, newOwnerId, currentUserId, cancellationToken);
    }
    private async Task TransferOwnershipCoreAsync(Guid houseId, Guid newOwnerId, Guid currentUserId, CancellationToken cancellationToken)
    {
        var currentMember = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, currentUserId, cancellationToken);
        if (currentMember == null || currentMember.Status != HouseMemberStatus.ACTIVE || currentMember.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can transfer ownership.");

        if (newOwnerId == currentUserId) throw new ConflictException("Choose another active member.");
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
        if (_mutations == null) { await SetMemberPreferencesCoreAsync(houseId, request, userId, cancellationToken); return; }

        await _mutations.RunAsync(houseId, () => SetMemberPreferencesCoreAsync(houseId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task SetMemberPreferencesCoreAsync(Guid houseId, SetMemberPreferencesRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        if (request.Preferences.Select(p => p.ChoreId).Distinct().Count() != request.Preferences.Count) throw new DomainException("Each chore may have only one preference.");
        var existingPrefs = await _unitOfWork.MemberPreferences.GetByUserIdAsync(userId, cancellationToken);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await InvalidateAllocationInputsAsync(houseId, cancellationToken);
            foreach (var pref in existingPrefs)
            {
                var chore = await _unitOfWork.Chores.GetByIdAsync(pref.ChoreId, cancellationToken);
                if (chore != null && chore.HouseId == houseId)
                {
                    _unitOfWork.MemberPreferences.Delete(pref);
                }
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
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
        if (_mutations == null) { await SetMemberConstraintCoreAsync(houseId, request, userId, cancellationToken); return; }

        await _mutations.RunAsync(houseId, () => SetMemberConstraintCoreAsync(houseId, request, userId, cancellationToken), cancellationToken);
    }

    private async Task SetMemberConstraintCoreAsync(Guid houseId, SetMemberConstraintRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException();

        if (request.MaxChoresPerWeek <= 0 || request.MaxEffortMinutesPerDay <= 0 || request.MaxEffortMinutesPerDay > 1440) throw new DomainException("Capacity must be positive and daily effort cannot exceed 1440 minutes.");
        var existing = await _unitOfWork.MemberConstraints.GetByUserAndHouseIdAsync(userId, houseId, cancellationToken);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await InvalidateAllocationInputsAsync(houseId, cancellationToken);
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
    private async Task EnsureNoOpenObligationsAsync(Guid houseId, Guid userId, CancellationToken ct)
    {
        var payments = await _unitOfWork.PaymentObligations.GetByHouseIdAsync(houseId, ct);
        if (payments.Any(p => (p.DebtorUserId == userId || p.CreditorUserId == userId) && p.Status is PaymentObligationStatus.PENDING or PaymentObligationStatus.DISPUTED))
            throw new ConflictException("Resolve outstanding payment obligations first.");
    }
}
