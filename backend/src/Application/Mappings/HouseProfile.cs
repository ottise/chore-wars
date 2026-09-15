using AutoMapper;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.House;

namespace ChoreWars.Application.Mappings;

public class HouseProfile : Profile
{
    public HouseProfile()
    {
        CreateMap<House, HouseResponse>();
        
        CreateMap<HouseMember, HouseMemberResponse>()
            .ForMember(dest => dest.DisplayName, opt => opt.MapFrom(src => src.User.DisplayName));
    }
}
