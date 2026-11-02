namespace ChoreWars.Application.Interfaces.Services;

public interface IPushDeviceService
{
    Task RegisterAsync(Guid userId, string token, string platform, CancellationToken cancellationToken = default);
    Task RevokeAsync(Guid userId, string token, CancellationToken cancellationToken = default);
}
