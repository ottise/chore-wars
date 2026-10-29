namespace ChoreWars.Application.Interfaces.Services;

public interface IEmailOtpService
{
    bool Required { get; }
    bool IsConfigured { get; }
    Task RequestAsync(string email, string purpose, CancellationToken ct);
    Task VerifyAsync(string email, string code, string? newPassword, CancellationToken ct);
}

public interface IAccountEmailSender
{
    bool IsConfigured { get; }
    Task SendCodeAsync(string email, string code, string purpose, CancellationToken ct);
}
