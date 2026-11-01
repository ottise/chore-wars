using System.Text.Json;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services.AI;
using ChoreWars.Application.Validations.AI;
using ChoreWars.Domain.Entities;
using FluentValidation;
using Moq;
using Xunit;

namespace UnitTests.Services;

public class AIAssistantChatHistoryTests
{
    private sealed class Mutations : IHouseMutationCoordinator
    {
        public Task RunAsync(Guid houseId, Func<Task> action, CancellationToken ct = default) => action();
        public Task<T> RunAsync<T>(Guid houseId, Func<Task<T>> action, CancellationToken ct = default) => action();
    }

    [Fact]
    public async Task InterpretAsyncSavesUserAndAssistantMessages()
    {
        var house = Guid.NewGuid();
        var actor = Guid.NewGuid();
        var addedMessages = new List<AIAssistantMessage>();

        var aiState = new Mock<IAIStateRepository>();
        aiState.Setup(x => x.AddAssistantMessage(It.IsAny<AIAssistantMessage>()))
            .Callback<AIAssistantMessage>(addedMessages.Add);

        var uow = new Mock<IUnitOfWork> { DefaultValue = DefaultValue.Mock };
        uow.Setup(x => x.HouseMembers.GetByHouseIdAsync(house, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        uow.Setup(x => x.Chores.GetByHouseIdAsync(house, It.IsAny<CancellationToken>())).ReturnsAsync([]);
        uow.Setup(x => x.Supplies.HouseSuppliersAsync(house, It.IsAny<CancellationToken>())).ReturnsAsync([]);

        var client = new Mock<IAIHousekeeperClient>();
        client.Setup(x => x.PostAsync(house, actor, "/v1/interpret", It.IsAny<object>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(JsonSerializer.SerializeToElement(new
            {
                intent = "general",
                summary = "Tôi có thể giúp bạn sắp xếp việc nhà.",
                missing_fields = Array.Empty<string>()
            }));

        var service = new AIHousekeeperService(
            uow.Object,
            aiState.Object,
            client.Object,
            Mock.Of<IAIContextBuilder>(),
            new Mutations(),
            Mock.Of<IHouseAccessService>(),
            TimeProvider.System,
            Mock.Of<IActionProposalService>(),
            Mock.Of<IScheduleChangeService>(),
            Mock.Of<IValidator<AIGenerateRequest>>(),
            new AITextRequestValidator(),
            Mock.Of<IValidator<AIAvailabilityChangeRequest>>(),
            Mock.Of<IValidator<AIObservationRequest>>());

        var result = await service.InterpretAsync(house, actor, new AITextRequest { Text = "Chào trợ lý" }, false, default);

        Assert.True(result.ValueKind != JsonValueKind.Undefined);
        Assert.Equal(2, addedMessages.Count);
        Assert.Equal("USER", addedMessages[0].Role);
        Assert.Equal("Chào trợ lý", addedMessages[0].Content);
        Assert.Equal("ASSISTANT", addedMessages[1].Role);
        Assert.Equal("Tôi có thể giúp bạn sắp xếp việc nhà.", addedMessages[1].Content);
    }

    [Fact]
    public async Task ChatHistoryAsyncReturnsFormattedHistory()
    {
        var house = Guid.NewGuid();
        var actor = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var aiState = new Mock<IAIStateRepository>();
        aiState.Setup(x => x.AssistantHistoryAsync(house, actor, 50, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<AIAssistantMessage>
            {
                new()
                {
                    Id = Guid.NewGuid(),
                    HouseId = house,
                    UserId = actor,
                    Role = "USER",
                    Content = "Tối mai tôi bận",
                    CreatedAt = now.AddMinutes(-5)
                },
                new()
                {
                    Id = Guid.NewGuid(),
                    HouseId = house,
                    UserId = actor,
                    Role = "ASSISTANT",
                    Content = "Đã ghi nhận bạn bận.",
                    PayloadJson = "{\"intent\":\"general\"}",
                    CreatedAt = now.AddMinutes(-4)
                }
            });

        var service = new AIHousekeeperService(
            Mock.Of<IUnitOfWork>(),
            aiState.Object,
            Mock.Of<IAIHousekeeperClient>(),
            Mock.Of<IAIContextBuilder>(),
            new Mutations(),
            Mock.Of<IHouseAccessService>(),
            TimeProvider.System,
            Mock.Of<IActionProposalService>(),
            Mock.Of<IScheduleChangeService>(),
            Mock.Of<IValidator<AIGenerateRequest>>(),
            new AITextRequestValidator(),
            Mock.Of<IValidator<AIAvailabilityChangeRequest>>(),
            Mock.Of<IValidator<AIObservationRequest>>());

        var history = await service.ChatHistoryAsync(house, actor, 50, default);
        var items = history.GetProperty("items").EnumerateArray().ToList();

        Assert.Equal(2, items.Count);
        Assert.Equal("user", items[0].GetProperty("role").GetString());
        Assert.Equal("Tối mai tôi bận", items[0].GetProperty("content").GetString());
        Assert.Equal("assistant", items[1].GetProperty("role").GetString());
        Assert.Equal("Đã ghi nhận bạn bận.", items[1].GetProperty("content").GetString());
    }

    [Fact]
    public async Task ClearChatHistoryAsyncCallsRepository()
    {
        var house = Guid.NewGuid();
        var actor = Guid.NewGuid();

        var aiState = new Mock<IAIStateRepository>();
        aiState.Setup(x => x.ClearAssistantHistoryAsync(house, actor, It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var service = new AIHousekeeperService(
            Mock.Of<IUnitOfWork>(),
            aiState.Object,
            Mock.Of<IAIHousekeeperClient>(),
            Mock.Of<IAIContextBuilder>(),
            new Mutations(),
            Mock.Of<IHouseAccessService>(),
            TimeProvider.System,
            Mock.Of<IActionProposalService>(),
            Mock.Of<IScheduleChangeService>(),
            Mock.Of<IValidator<AIGenerateRequest>>(),
            new AITextRequestValidator(),
            Mock.Of<IValidator<AIAvailabilityChangeRequest>>(),
            Mock.Of<IValidator<AIObservationRequest>>());

        var result = await service.ClearChatHistoryAsync(house, actor, default);

        Assert.True(result.GetProperty("success").GetBoolean());
        aiState.Verify(x => x.ClearAssistantHistoryAsync(house, actor, It.IsAny<CancellationToken>()), Times.Once);
    }
}
