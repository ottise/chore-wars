using AutoMapper;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Bounty;

namespace ChoreWars.Application.Mappings;

public class BountyProfile : Profile
{
    public BountyProfile()
    {
        CreateMap<ChoreBounty, BountyResponse>()
            .ForMember(dest => dest.ChoreName, opt => opt.MapFrom(src => src.ChoreOccurrence.Chore.Name))
            .ForMember(dest => dest.PostedByDisplayName, opt => opt.MapFrom(src => src.PostedByUser.DisplayName));
    }
}
