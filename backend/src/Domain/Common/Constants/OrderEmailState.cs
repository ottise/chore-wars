namespace ChoreWars.Domain.Common.Constants;
public static class OrderEmailState
{
    public const string Queued = "QUEUED";
    public const string Sending = "SENDING";
    public const string Sent = "SENT";
    public const string Failed = "FAILED";
    public const string Unknown = "UNKNOWN";
    public const string NotRequested = "NOT_REQUESTED";
    public const string UserReported = "USER_REPORTED";
    public const string ProviderVerified = "PROVIDER_VERIFIED";
}
