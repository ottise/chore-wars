using ChoreWars.Domain.Enums;
using System.Text.Json.Serialization;

namespace ChoreWars.Application.DTOs.Proposal;

public class CreateProposalRequest
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ProposalType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string PayloadJson { get; set; } = "{}";
    public List<Guid> TargetUserIds { get; set; } = new();
    public DateTime? ExpiresAt { get; set; }
}

public class RespondProposalRequest
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ConfirmationStatus Status { get; set; }
    public string? Reason { get; set; }
}

public class ActionProposalResponse
{
    public Guid Id { get; set; }
    public Guid HouseId { get; set; }
    public Guid RoomId { get; set; }
    public Guid CreatorId { get; set; }
    public string? CreatorName { get; set; }
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ProposalType Type { get; set; }
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ProposalStatus Status { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string PayloadJson { get; set; } = "{}";
    public DateTime CreatedAt { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public List<ProposalConfirmationResponse> Confirmations { get; set; } = new();
}

public class ProposalConfirmationResponse
{
    public Guid Id { get; set; }
    public Guid TargetUserId { get; set; }
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ConfirmationStatus Status { get; set; }
    public string? Reason { get; set; }
    public DateTime? RespondedAt { get; set; }
}

public class ChoreSwapPayload
{
    public Guid SourceOccurrenceId { get; set; }
    public Guid TargetOccurrenceId { get; set; }
}

public class UrgentEventPayload
{
    public string? Title { get; set; }
    public DateTime? ReadyByUtc { get; set; }
    public int? GuestCount { get; set; }
    public string? PlanVersion { get; set; }
    public Guid SeasonId { get; set; }
    public int DeadlineMinutes { get; set; }
    public List<UrgentChoreItem> Chores { get; set; } = new();
}

public class UrgentChoreItem
{
    public string? PlanKey { get; set; }
    public int PlannedOffsetMinutes { get; set; }
    public List<string> DependsOn { get; set; } = [];
    public List<string> Resources { get; set; } = [];
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int KarmaPoints { get; set; }
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ChoreEffort Difficulty { get; set; } = ChoreEffort.MEDIUM;
    public Guid AssignedUserId { get; set; }
}
