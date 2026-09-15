using AutoMapper;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Notification;

namespace ChoreWars.Application.Mappings;

public class NotificationProfile : Profile
{
    public NotificationProfile()
    {
        CreateMap<Notification, NotificationResponse>();
    }
}
