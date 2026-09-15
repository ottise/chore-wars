using AutoMapper;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Season;

namespace ChoreWars.Application.Mappings;

public class SeasonProfile : Profile
{
    public SeasonProfile()
    {
        CreateMap<ChoreSeason, SeasonResponse>();
        
        CreateMap<SeasonRanking, SeasonRankingResponse>()
            .ForMember(dest => dest.DisplayName, opt => opt.MapFrom(src => src.User.DisplayName));
    }
}
