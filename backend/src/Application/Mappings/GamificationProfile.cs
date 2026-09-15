using AutoMapper;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Gamification;

namespace ChoreWars.Application.Mappings;

public class GamificationProfile : Profile
{
    public GamificationProfile()
    {
        CreateMap<Reward, RewardResponse>();
        CreateMap<Achievement, AchievementResponse>();
    }
}
