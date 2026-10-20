using System.Collections.Concurrent;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.SignalR;
namespace ChoreWars.Presentation.Hubs;
public sealed class ChatConnectionRegistry {
    private readonly ConcurrentDictionary<(Guid Room,Guid User,string Connection),Action> _connections = new();
    public void Add(Guid room,Guid user,string connection,Action abort) => _connections[(room,user,connection)] = abort;
    public void Remove(string connection) { foreach(var key in _connections.Keys.Where(k=>k.Connection==connection)) _connections.TryRemove(key,out _); }
    public IReadOnlyList<(string Connection,Action Abort)> For(Guid room,Guid user) => _connections.Where(p=>p.Key.Room==room && p.Key.User==user).Select(p=>(p.Key.Connection,p.Value)).ToList();
}
public sealed class HouseRealtimeAccess(ChatConnectionRegistry registry,IHubContext<ChatHub> hub,IAfterCommitActions afterCommit) : IHouseRealtimeAccess {
    public void Revoke(Guid roomId,Guid userId) => afterCommit.Enqueue(async () => {
        foreach(var connection in registry.For(roomId,userId)) {
            await hub.Groups.RemoveFromGroupAsync(connection.Connection,ChatHub.RoomGroup(roomId));
            connection.Abort(); registry.Remove(connection.Connection);
        }
    });
}
