using System.Text.Json;
using ChoreWars.Application.Services.AI;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Validations.AI;
using ChoreWars.Domain.Enums;
using FluentValidation;
using Moq;

namespace UnitTests.Services;

public class AIBountyContractTests
{
    private sealed class Mutations : IHouseMutationCoordinator
    {
        public Task RunAsync(Guid houseId, Func<Task> action, CancellationToken ct = default) => action();
        public Task<T> RunAsync<T>(Guid houseId, Func<Task<T>> action, CancellationToken ct = default) => action();
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task InterpretOnlyExposesOwnEligibleChoresAndRechecksBeforeReturning(bool changedDuringInference)
    {
        var house = Guid.NewGuid(); var actor = Guid.NewGuid(); var now = DateTime.UtcNow;
        var season = new ChoreSeason { Id = Guid.NewGuid(), HouseId = house, Status = SeasonStatus.ACTIVE, StartDate = now.AddDays(-1) };
        ChoreOccurrence TaskFor(Guid assignee) => new() { Id = Guid.NewGuid(), SeasonId = season.Id,
            AssignedUserId = assignee, Status = ChoreOccurrenceStatus.ASSIGNED, DueDate = now.AddDays(1),
            Chore = new Chore { Id = Guid.NewGuid(), HouseId = house, Name = "Kitchen" } };
        var own = TaskFor(actor); var other = TaskFor(Guid.NewGuid()); var expired = TaskFor(actor);
        expired.DueDate = now.AddDays(-1);
        var completed = TaskFor(actor); completed.Status = ChoreOccurrenceStatus.COMPLETED;
        var posted = TaskFor(actor);
        var uow = new Mock<IUnitOfWork> { DefaultValue = DefaultValue.Mock };
        uow.Setup(x => x.HouseMembers.GetByHouseIdAsync(house, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        uow.Setup(x => x.Chores.GetByHouseIdAsync(house, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        uow.Setup(x => x.ChoreOccurrences.GetUnresolvedByHouseIdAsync(house, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        uow.Setup(x => x.ChoreOccurrences.GetBySeasonIdAsync(season.Id, It.IsAny<CancellationToken>())).ReturnsAsync([own, other, expired, completed, posted]);
        uow.Setup(x => x.Seasons.GetActiveSeasonByHouseIdAsync(house, It.IsAny<CancellationToken>())).ReturnsAsync(season);
        uow.Setup(x => x.ChoreBounties.GetBountiesByHouseIdAsync(house, It.IsAny<CancellationToken>()))
            .ReturnsAsync([new ChoreBounty { ChoreOccurrenceId = posted.Id, Status = BountyStatus.OPEN }]);
        uow.Setup(x => x.Supplies.HouseSuppliersAsync(house, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        var client = new Mock<IAIHousekeeperClient>();
        client.Setup(x => x.PostAsync(house, actor, "/v1/interpret", It.IsAny<object>(), It.IsAny<CancellationToken>()))
            .Returns<Guid, Guid, string, object, CancellationToken>((_, _, _, input, _) => {
                var context = JsonSerializer.SerializeToElement(input).GetProperty("bounty_chores");
                Assert.Single(context.EnumerateObject());
                Assert.True(context.TryGetProperty(own.Id.ToString(), out _));
                if (changedDuringInference) own.Status = ChoreOccurrenceStatus.COMPLETED;
                return Task.FromResult(JsonSerializer.SerializeToElement(new { intent = "bounty_create",
                    summary = "Review bounty", bounty = new { occurrence_id = own.Id, amount = 20000 } }));
            });
        var service = new AIHousekeeperService(uow.Object, Mock.Of<IAIStateRepository>(), client.Object,
            Mock.Of<IAIContextBuilder>(), new Mutations(), Mock.Of<IHouseAccessService>(), TimeProvider.System,
            Mock.Of<IActionProposalService>(), Mock.Of<IScheduleChangeService>(), Mock.Of<IValidator<AIGenerateRequest>>(),
            new AITextRequestValidator(), Mock.Of<IValidator<AIAvailabilityChangeRequest>>(), Mock.Of<IValidator<AIObservationRequest>>());
        var request = new AITextRequest { Text = "Post my kitchen bounty for 20000 VND" };
        if (changedDuringInference)
            await Assert.ThrowsAsync<ConflictException>(() => service.InterpretAsync(house, actor, request, false, default));
        else
        {
            var result = await service.InterpretAsync(house, actor, request, false, default);
            Assert.Equal("Kitchen", result.GetProperty("bounty").GetProperty("chore_name").GetString());
        }
        uow.Verify(x => x.ChoreBounties.AddAsync(It.IsAny<ChoreBounty>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public void BountyUsesCurrentChoreMetadataWithoutSecondConfirmation()
    {
        var occurrence = new ChoreOccurrence { Id = Guid.NewGuid(), DueDate = DateTime.UtcNow.AddDays(1), Chore = new Chore { Name = "Kitchen" } };
        var result = AIBountyContract.ValidateAndGround(JsonSerializer.SerializeToElement(new {
            intent = "bounty_create", requires_confirmation = false,
            bounty = new { occurrence_id = occurrence.Id, amount = 20000, chore_name = "Invented name" }
        }), new Dictionary<Guid, ChoreOccurrence> { [occurrence.Id] = occurrence });
        Assert.False(result.GetProperty("requires_confirmation").GetBoolean());
        Assert.Equal("Kitchen", result.GetProperty("bounty").GetProperty("chore_name").GetString());
        Assert.Equal(occurrence.DueDate, result.GetProperty("bounty").GetProperty("due_at").GetDateTime());
    }

    [Fact]
    public void ForeignOrStaleOccurrenceIsRejected()
    {
        var result = JsonSerializer.SerializeToElement(new { intent = "bounty_create", bounty = new { occurrence_id = Guid.NewGuid(), amount = 20000 } });
        Assert.Throws<ConflictException>(() => AIBountyContract.ValidateAndGround(result, new Dictionary<Guid, ChoreOccurrence>()));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(1.5)]
    public void InvalidAmountIsRejected(decimal amount)
    {
        var result = JsonSerializer.SerializeToElement(new { intent = "bounty_create", bounty = new { amount } });
        Assert.Throws<ConflictException>(() => AIBountyContract.ValidateAndGround(result, new Dictionary<Guid, ChoreOccurrence>()));
    }

    [Fact]
    public void MissingFieldsPreventReviewEvenWhenProviderOmitsThem()
    {
        var result = AIBountyContract.ValidateAndGround(JsonSerializer.SerializeToElement(new { intent = "bounty_create", bounty = new { } }), new Dictionary<Guid, ChoreOccurrence>());
        Assert.Equal(2, result.GetProperty("missing_fields").GetArrayLength());
    }

    [Fact]
    public void MissingCandidateStillRequestsDetailsBeforeAutomaticPosting()
    {
        var result = AIBountyContract.ValidateAndGround(JsonSerializer.SerializeToElement(new { intent = "bounty_create", requires_confirmation = false }), new Dictionary<Guid, ChoreOccurrence>());
        Assert.Equal(2, result.GetProperty("missing_fields").GetArrayLength());
        Assert.False(result.GetProperty("requires_confirmation").GetBoolean());
    }
}
