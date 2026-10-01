using AutoMapper;
using System.Linq;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.DTOs.Chore;

namespace ChoreWars.Application.Mappings;

public class ChoreProfile : Profile
{
    public ChoreProfile()
    {
        CreateMap<Chore, ChoreResponse>()
            .ForMember(dest => dest.FrequencyDays, opt => opt.MapFrom(src =>
                src.FrequencyDays.Select(day => day.DayOfWeek)));
        
        CreateMap<ChoreOccurrence, ChoreOccurrenceResponse>()
            .ForMember(dest => dest.ChoreName, opt => opt.MapFrom(src => src.Chore.Name))
            .ForMember(dest => dest.AssignedUserDisplayName, opt => opt.MapFrom(src =>
                src.AssignedUser == null ? "Unassigned" : src.AssignedUser.DisplayName))
            .ForMember(dest => dest.Description, opt => opt.MapFrom(src => src.Chore.Description))
            .ForMember(dest => dest.KarmaPoints, opt => opt.MapFrom(src =>
                src.SnapshotKarma > 0 ? src.SnapshotKarma : src.Chore.KarmaPoints))
            .ForMember(dest => dest.Type, opt => opt.MapFrom(src => src.Chore.Type))
            .ForMember(dest => dest.Difficulty, opt => opt.MapFrom(src => src.Chore.Difficulty))
            .ForMember(dest => dest.EstimatedMinutes, opt => opt.MapFrom(src => src.Chore.EstimatedMinutes));
    }
}
