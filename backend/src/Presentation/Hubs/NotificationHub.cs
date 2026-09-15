using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace ChoreWars.Presentation.Hubs;

public class NotificationHub : Hub
{
    // Clients can connect to this hub to receive real-time notifications,
    // e.g. when a chore is completed or a bounty is posted.
    public async Task SendNotification(string user, string message)
    {
        await Clients.All.SendAsync("ReceiveNotification", user, message);
    }
}
