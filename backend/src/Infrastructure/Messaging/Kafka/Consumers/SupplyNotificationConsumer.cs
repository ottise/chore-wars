using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Chat;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
namespace ChoreWars.Infrastructure.Messaging.Kafka.Consumers;
public sealed class SupplyNotificationConsumer(IOptions<KafkaOptions> options,IServiceScopeFactory scopes,ILogger<SupplyNotificationConsumer> log)
 :KafkaConsumerBase<SupplyNotificationEvent>(KafkaTopics.SUPPLY_NOTIFICATION,options,scopes,log)
{
 protected override async Task ProcessEventAsync(SupplyNotificationEvent e,IServiceProvider services,CancellationToken ct){
  var uow=services.GetRequiredService<IUnitOfWork>();var notifications=services.GetRequiredService<INotificationService>();
  var members=(await uow.HouseMembers.GetByHouseIdAsync(e.HouseId,ct)).Where(x=>x.Status==HouseMemberStatus.ACTIVE).ToList();
  foreach(var m in members.Where(x=>!x.ChatNotificationsMuted&&(!e.RecipientId.HasValue||x.UserId==e.RecipientId))){
   await notifications.CreateNotificationAsync(m.UserId,e.HouseId,e.Title,e.Message,nameof(NotificationType.SUPPLY_UPDATE),e.ResourceType,e.ResourceId,ct);
  }
  if(!e.RecipientId.HasValue){
   var sender=members.FirstOrDefault(x=>x.UserId==e.ActorId)??members.FirstOrDefault(x=>x.Role==HouseRole.OWNER);
   if(sender!=null){var room=await uow.Chats.GetRoomByHouseIdAsync(e.HouseId,ct);
    if(room==null){room=new ChatRoom{Id=Guid.NewGuid(),HouseId=e.HouseId,Name="Household Chat",CreatedAt=DateTime.UtcNow};await uow.Chats.AddRoomAsync(room,ct);}
    var message=new ChatMessage{Id=e.EventId,ClientMessageId=e.EventId,RoomId=room.Id,SenderId=sender.UserId,MessageType="SUPPLY_CARD",CreatedAt=DateTime.UtcNow,
     Content=JsonSerializer.Serialize(new{houseId=e.HouseId,resourceId=e.ResourceId,resourceType=e.ResourceType,title=e.Title,message=e.Message})};
    await uow.Chats.AddMessageAsync(message,ct);
    var response=new ChatMessageResponse{Id=message.Id,ClientMessageId=message.ClientMessageId,RoomId=message.RoomId,SenderId=message.SenderId,SenderName="Household Supplies",MessageType=message.MessageType,Content=message.Content,CreatedAt=message.CreatedAt};
    services.GetRequiredService<IAfterCommitActions>().Enqueue(()=>services.GetRequiredService<ISupplyChatPublisher>().PublishAsync(response,CancellationToken.None));
   }
  }
 }
}
