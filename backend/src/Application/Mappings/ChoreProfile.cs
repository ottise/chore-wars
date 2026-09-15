using AutoMapper;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Chore;

namespace ChoreWars.Application.Mappings;

public class ChoreProfile : Profile
{
    public ChoreProfile()
    {
        CreateMap<Chore, ChoreResponse>();
        
        CreateMap<ChoreOccurrence, ChoreOccurrenceResponse>()
            .ForMember(dest => dest.ChoreName, opt => opt.MapFrom(src => src.Chore.Name))
            .ForMember(dest => dest.AssignedUserDisplayName, opt => opt.MapFrom(src => src.AssignedUser.DisplayName));
    }
}
