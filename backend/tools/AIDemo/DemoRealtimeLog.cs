using System.Text.Json;
using ChoreWars.Application.DTOs.Notification;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Services;

namespace AIDemo;

public sealed class DemoRealtimeLog(string path) : IActionProposalRealtimePublisher, INotificationRealtimePublisher
{
    private Task WriteAsync(string kind, Guid id, CancellationToken ct)=>File.AppendAllTextAsync(path,JsonSerializer.Serialize(new{kind,id,transport="DEMO_AUDIT_FILE",delivered_to_device=false})+Environment.NewLine,ct);
    public Task ProposalCreatedAsync(ActionProposalResponse proposal,CancellationToken ct=default)=>WriteAsync("proposal.created",proposal.Id,ct);
    public Task ProposalUpdatedAsync(ActionProposalResponse proposal,CancellationToken ct=default)=>WriteAsync("proposal.updated",proposal.Id,ct);
    public Task PublishAsync(NotificationResponse notification,CancellationToken ct=default)=>WriteAsync("notification.created",notification.Id,ct);
}
