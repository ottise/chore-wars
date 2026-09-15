using AutoMapper;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Auth;

namespace ChoreWars.Application.Mappings;

public class UserProfile : Profile
{
    public UserProfile()
    {
        CreateMap<User, LoginResponse>()
            .ForMember(dest => dest.UserId, opt => opt.MapFrom(src => src.Id))
            .ForMember(dest => dest.Token, opt => opt.Ignore())
            .ForMember(dest => dest.RefreshToken, opt => opt.Ignore());
            
        CreateMap<User, ChoreWars.Application.DTOs.User.UserProfileResponse>();
    }
}
