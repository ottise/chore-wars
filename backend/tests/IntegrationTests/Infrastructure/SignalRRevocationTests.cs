using System.Net;
using ChoreWars.Application.DTOs.Chat;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;

public class SignalRRevocationTests
{
    [PostgresTheory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task TextRetryThroughHubReturnsThePersistedMessageAndOneOutboxEvent(bool everyone)
    {
        await using var fixture = await PostgresFixture.CreateAsync();
        var seed = await CoreConcurrencyTests.Seed(fixture);
        await using var factory = new ApiFactory(fixture);
        Guid room;
        await using (var scope = factory.Services.CreateAsyncScope())
            room = (await scope.ServiceProvider.GetRequiredService<IChatService>().GetHouseRoomAsync(seed.HouseId, seed.Users[0])).Id;
        await using var connection = await Connect(factory, seed.Users[0]);
        await connection.InvokeAsync("JoinRoom", room);
        var request = Guid.NewGuid();
        var content = everyone ? "@all alo" : $"@{{{seed.Users[1]}}} xem lịch giúp mình";
        var first = await connection.InvokeAsync<ChatMessageResponse>("SendText", room, content, request);
        var retry = await connection.InvokeAsync<ChatMessageResponse>("SendText", room, content, request);
        Assert.Equal(first.Id, retry.Id); Assert.Equal(request, retry.ClientMessageId);
        await using var check = factory.Services.CreateAsyncScope();
        var db = check.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.ChatMessages.CountAsync());
        Assert.Equal(1, await db.OutboxMessages.CountAsync());
        var payload = System.Text.Json.JsonSerializer.Deserialize<ChoreWars.Application.Events.ChatMessageCreatedEvent>((await db.OutboxMessages.SingleAsync()).Payload)!;
        Assert.Equal(everyone ? 2 : 1, payload.MentionedIds.Length);
        Assert.DoesNotContain(seed.Users[0], payload.MentionedIds);
        var error = await Assert.ThrowsAsync<Microsoft.AspNetCore.SignalR.HubException>(() =>
            connection.InvokeAsync<ChatMessageResponse>("SendText", room, $"@{{{Guid.NewGuid()}}} alo", Guid.NewGuid()));
        Assert.Contains("Only active members", error.Message);
        Assert.Equal(1, await db.ChatMessages.CountAsync());
    }

    private static async Task<HubConnection> Connect(ApiFactory factory, Guid userId)
    {
        using var scope=factory.Services.CreateScope();
        var user=await scope.ServiceProvider.GetRequiredService<AppDbContext>().Users.SingleAsync(x=>x.Id==userId);
        var token=scope.ServiceProvider.GetRequiredService<IAuthTokenProvider>().GenerateJwtToken(user);
        var hub=new HubConnectionBuilder().WithUrl(new Uri(factory.Server.BaseAddress,"/hubs/chat"),options=> {
            options.Transports=HttpTransportType.LongPolling;
            options.HttpMessageHandlerFactory=_=>factory.Server.CreateHandler();
            options.AccessTokenProvider=()=>Task.FromResult<string?>(token);
        }).Build();
        await hub.StartAsync();return hub;
    }

    [PostgresTheory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task MembershipRemovalRevokesEveryConnectionAndOwnerKeepsChatAccess(bool kick)
    {
        await using var dbFixture=await PostgresFixture.CreateAsync();var seed=await CoreConcurrencyTests.Seed(dbFixture);
        await using var factory=new ApiFactory(dbFixture);
        Guid room;
        await using(var scope=factory.Services.CreateAsyncScope()) room=(await scope.ServiceProvider.GetRequiredService<IChatService>().GetHouseRoomAsync(seed.HouseId,seed.Users[0])).Id;
        await using var owner=await Connect(factory,seed.Users[0]);
        await using var first=await Connect(factory,seed.Users[1]);
        await using var second=await Connect(factory,seed.Users[1]);
        var closed1=new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var closed2=new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        first.Closed+=_=>{closed1.TrySetResult();return Task.CompletedTask;};
        second.Closed+=_=>{closed2.TrySetResult();return Task.CompletedTask;};
        await owner.InvokeAsync("JoinRoom",room);await first.InvokeAsync("JoinRoom",room);await second.InvokeAsync("JoinRoom",room);
        await using(var scope=factory.Services.CreateAsyncScope()) {
            var houses=scope.ServiceProvider.GetRequiredService<IHouseService>();
            if(kick) await houses.KickMemberAsync(seed.HouseId,seed.Users[1],seed.Users[0]);
            else await houses.LeaveHouseAsync(seed.HouseId,seed.Users[1]);
        }
        await Task.WhenAll(closed1.Task,closed2.Task).WaitAsync(TimeSpan.FromSeconds(20));
        Assert.Equal(HubConnectionState.Disconnected,first.State);Assert.Equal(HubConnectionState.Disconnected,second.State);
        var received=new TaskCompletionSource<ChatMessageResponse>(TaskCreationOptions.RunContinuationsAsynchronously);
        owner.On<ChatMessageResponse>("MessageReceived",message=>received.TrySetResult(message));
        await owner.InvokeAsync("SendMessage",room,"after-kick-marker");
        Assert.Equal("after-kick-marker",(await received.Task.WaitAsync(TimeSpan.FromSeconds(10))).Content);
        await using var reconnect=await Connect(factory,seed.Users[1]);
        await Assert.ThrowsAsync<Microsoft.AspNetCore.SignalR.HubException>(()=>reconnect.InvokeAsync("JoinRoom",room));
    }
}
