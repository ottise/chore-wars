namespace ChoreWars.Application.DTOs.Notification;

public sealed class PushDeviceRequest
{
    public string Token { get; set; } = string.Empty;
    public string Platform { get; set; } = "ANDROID";
}
