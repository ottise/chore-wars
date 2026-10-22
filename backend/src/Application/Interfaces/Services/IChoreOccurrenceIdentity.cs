namespace ChoreWars.Application.Interfaces.Services;

public interface IChoreOccurrenceIdentity
{
    Guid ForDate(Guid templateId, DateOnly date);
}
