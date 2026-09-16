using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public class SeasonService : ISeasonService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IChoreGenerationService _generationService;
    private readonly IChoreAllocationService _allocationService;

    public SeasonService(IUnitOfWork unitOfWork, IMapper mapper, IChoreGenerationService generationService, IChoreAllocationService allocationService)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _generationService = generationService;
        _allocationService = allocationService;
    }

    public async Task<SeasonResponse> CreateSeasonAsync(Guid houseId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(houseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can create a season.");

        var activeSeason = await _unitOfWork.Seasons.GetActiveSeasonByHouseIdAsync(houseId, cancellationToken);
        if (activeSeason != null)
            throw new ConflictException("There is already an active season in this house.");

        var season = new ChoreSeason
        {
            Id = Guid.NewGuid(),
            HouseId = houseId,
            Name = request.Name,
            StartDate = request.StartDate.ToUniversalTime(),
            EndDate = request.EndDate.ToUniversalTime(),
            Status = SeasonStatus.DRAFT,
            AllocationMethod = request.AllocationMethod
        };

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Seasons.AddAsync(season, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<SeasonResponse>(season);
    }

    public async Task StartSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can start a season.");

        if (season.Status != SeasonStatus.DRAFT)
            throw new ConflictException("Season must be in DRAFT state to start.");

        season.Status = SeasonStatus.ACTIVE;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.Seasons.Update(season);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task EndSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can end a season.");

        if (season.Status != SeasonStatus.ACTIVE)
            throw new ConflictException("Season must be in ACTIVE state to end.");

        season.Status = SeasonStatus.COMPLETED;

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.Seasons.Update(season);
            // Reward calculation could be triggered here or via a Kafka event.
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }

    public async Task SetAvailabilityAsync(Guid seasonId, MemberAvailabilityRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Status != HouseMemberStatus.ACTIVE)
            throw new ForbiddenException("You must be an active member of the house.");

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            var existingAvailabilities = await _unitOfWork.MemberAvailabilities.GetBySeasonAndUserIdAsync(seasonId, userId, cancellationToken);
            foreach (var existing in existingAvailabilities)
            {
                _unitOfWork.MemberAvailabilities.Delete(existing);
            }

            foreach (var kvp in request.Availabilities)
            {
                var availability = new MemberAvailability
                {
                    Id = Guid.NewGuid(),
                    SeasonId = seasonId,
                    UserId = userId,
                    DayOfWeek = kvp.Key,
                    IsAvailable = kvp.Value
                };
                await _unitOfWork.MemberAvailabilities.AddAsync(availability, cancellationToken);
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

    public async Task<IEnumerable<SeasonRankingResponse>> GetRankingsAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null)
            throw new ForbiddenException();

        var rankings = await _unitOfWork.SeasonRankings.GetBySeasonIdAsync(seasonId, cancellationToken);
        return _mapper.Map<IEnumerable<SeasonRankingResponse>>(rankings);
    }

    public async Task<SeasonResponse> CloneSeasonAsync(Guid seasonId, CreateSeasonRequest request, Guid userId, CancellationToken cancellationToken = default)
    {
        var originalSeason = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (originalSeason == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(originalSeason.HouseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can clone a season.");

        var activeSeason = await _unitOfWork.Seasons.GetActiveSeasonByHouseIdAsync(originalSeason.HouseId, cancellationToken);
        if (activeSeason != null)
            throw new ConflictException("There is already an active season in this house.");

        var newSeason = new ChoreSeason
        {
            Id = Guid.NewGuid(),
            HouseId = originalSeason.HouseId,
            Name = request.Name,
            StartDate = request.StartDate.ToUniversalTime(),
            EndDate = request.EndDate.ToUniversalTime(),
            Status = SeasonStatus.DRAFT,
            AllocationMethod = request.AllocationMethod
        };

        var originalChores = await _unitOfWork.Chores.GetBySeasonIdAsync(seasonId, cancellationToken);

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            await _unitOfWork.Seasons.AddAsync(newSeason, cancellationToken);

            foreach (var oldChore in originalChores)
            {
                var newChore = new Chore
                {
                    Id = Guid.NewGuid(),
                    HouseId = newSeason.HouseId,
                    SeasonId = newSeason.Id,
                    Name = oldChore.Name,
                    Description = oldChore.Description,
                    KarmaPoints = oldChore.KarmaPoints,
                    Type = oldChore.Type,
                    FrequencyType = oldChore.FrequencyType,
                    FrequencyValue = oldChore.FrequencyValue
                };
                
                foreach (var oldDay in oldChore.FrequencyDays)
                {
                    newChore.FrequencyDays.Add(new ChoreFrequencyDay
                    {
                        Id = Guid.NewGuid(),
                        ChoreId = newChore.Id,
                        DayOfWeek = oldDay.DayOfWeek
                    });
                }
                
                await _unitOfWork.Chores.AddAsync(newChore, cancellationToken);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }

        return _mapper.Map<SeasonResponse>(newSeason);
    }

    public async Task GenerateScheduleAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        var member = await _unitOfWork.HouseMembers.GetByHouseAndUserIdAsync(season.HouseId, userId, cancellationToken);
        if (member == null || member.Role != HouseRole.OWNER)
            throw new ForbiddenException("Only the house owner can generate a schedule.");

        if (season.Status != SeasonStatus.DRAFT)
            throw new ConflictException("Season must be in DRAFT state to generate schedule.");

        // 1. Generate all occurrences for the season
        await _generationService.GenerateOccurrencesAsync(seasonId, userId);

        // 2. Allocate chores
        await _allocationService.AllocateSeasonAsync(seasonId, cancellationToken);

        // 3. Update Season status to REVIEWING
        season.Status = SeasonStatus.REVIEWING;
        
        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            _unitOfWork.Seasons.Update(season);

            // 4. Create SeasonConfirmation records for all active members
            var activeMembers = await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken);
            foreach (var activeMember in activeMembers.Where(m => m.Status == HouseMemberStatus.ACTIVE))
            {
                var confirmation = new SeasonConfirmation
                {
                    Id = Guid.NewGuid(),
                    SeasonId = seasonId,
                    UserId = activeMember.UserId,
                    Status = ConfirmationStatus.PENDING,
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.SeasonConfirmations.AddAsync(confirmation, cancellationToken);
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

    public async Task ConfirmSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        if (season.Status != SeasonStatus.REVIEWING)
            throw new ConflictException("Season must be in REVIEWING state to confirm.");

        var confirmation = await _unitOfWork.SeasonConfirmations.GetBySeasonAndUserIdAsync(seasonId, userId, cancellationToken);
        if (confirmation == null)
            throw new ForbiddenException("You are not eligible to confirm this season.");

        if (confirmation.Status == ConfirmationStatus.CONFIRMED)
            throw new ConflictException("You have already confirmed this season.");

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            confirmation.Status = ConfirmationStatus.CONFIRMED;
            _unitOfWork.SeasonConfirmations.Update(confirmation);

            // Check if all active members have confirmed
            var activeMembers = (await _unitOfWork.HouseMembers.GetByHouseIdAsync(season.HouseId, cancellationToken))
                .Where(m => m.Status == HouseMemberStatus.ACTIVE)
                .ToList();
            var allConfirmations = await _unitOfWork.SeasonConfirmations.GetBySeasonIdAsync(seasonId, cancellationToken);
            
            bool allConfirmed = activeMembers.All(m => 
                allConfirmations.Any(c => c.UserId == m.UserId && c.Status == ConfirmationStatus.CONFIRMED) || 
                m.UserId == userId); // Handle current user who just confirmed

            if (allConfirmed)
            {
                season.Status = SeasonStatus.ACTIVE;
                _unitOfWork.Seasons.Update(season);
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

    public async Task RejectSeasonAsync(Guid seasonId, Guid userId, CancellationToken cancellationToken = default)
    {
        var season = await _unitOfWork.Seasons.GetByIdAsync(seasonId, cancellationToken);
        if (season == null)
            throw new NotFoundException(nameof(ChoreSeason), seasonId);

        if (season.Status != SeasonStatus.REVIEWING)
            throw new ConflictException("Season must be in REVIEWING state to reject.");

        var confirmation = await _unitOfWork.SeasonConfirmations.GetBySeasonAndUserIdAsync(seasonId, userId, cancellationToken);
        if (confirmation == null)
            throw new ForbiddenException("You are not eligible to reject this season.");

        await _unitOfWork.BeginTransactionAsync(cancellationToken);
        try
        {
            season.Status = SeasonStatus.DRAFT;
            _unitOfWork.Seasons.Update(season);

            await _unitOfWork.SeasonConfirmations.DeleteBySeasonIdAsync(seasonId, cancellationToken);
            await _unitOfWork.ChoreOccurrences.DeleteBySeasonIdAsync(seasonId, cancellationToken);

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await _unitOfWork.CommitTransactionAsync(cancellationToken);
        }
        catch
        {
            await _unitOfWork.RollbackTransactionAsync(cancellationToken);
            throw;
        }
    }
}
