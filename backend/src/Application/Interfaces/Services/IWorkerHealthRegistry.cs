using ChoreWars.Application.DTOs.Deployment;

namespace ChoreWars.Application.Interfaces.Services;

public interface IWorkerHealthRegistry
{
    void Heartbeat(string name);
    void Stopped(string name);
    IReadOnlyList<DependencyStatusResponse> Snapshot();
}
