namespace ChoreWars.Infrastructure.Payments;
public sealed class PayOsOptions
{
    public bool Enabled { get; set; }
    public Guid OperatorUserId { get; set; }
    public string ClientId { get; set; } = "";
    public string ApiKey { get; set; } = "";
    public string ChecksumKey { get; set; } = "";
    public string AccountNumber { get; set; } = "";
    public string WebBaseUrl { get; set; } = "";
}
