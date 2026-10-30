namespace ChoreWars.Domain.Common.Constants;

public static class AIConstants
{
    public const string TelemetryTopic = "ai.telemetry.v1";
    public const string Draft = "DRAFT";
    public const string Ready = "READY";
    public const string Generating = "GENERATING";
    public const string Applied = "APPLIED";
    public const string Rejected = "REJECTED";
    public const string Stale = "STALE";
    public const string Failed = "FAILED";
    public const string Allocation = "ALLOCATION";
    public const string Replan = "REPLAN";
    public const string Swap = "SWAP";
    public const string Evolution = "EVOLUTION";
    public const string Urgent = "URGENT";
    public const string Accepted = "ACCEPTED";
    public const int UrgentMaxDeadlineMinutes = 48 * 60;
    public const int RecommendationLifetimeMinutes = 15;
    public const int SchemaVersion = 1;
}
