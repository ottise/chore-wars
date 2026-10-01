using ChoreWars.Domain.Common.Constants;

namespace ChoreWars.Application.DTOs.House;

public class SetMemberConstraintRequest
{
    public int MaxChoresPerWeek { get; set; } = AIAllocationConstants.DefaultMaxChoresPerWeek;
    public int MaxEffortMinutesPerDay { get; set; } = AIAllocationConstants.DefaultMaxEffortMinutesPerDay;
}
