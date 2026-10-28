namespace ChoreWars.Application.Interfaces.Services;
public interface ISupplyOrderEmailSender
{
    bool IsConfigured { get; }
    Task SendAsync(Guid dispatchId, string recipient, string subject, string body, CancellationToken ct);
}
