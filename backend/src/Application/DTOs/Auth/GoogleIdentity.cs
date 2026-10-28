namespace ChoreWars.Application.DTOs.Auth;

public sealed record GoogleIdentity(string Subject, string Email, string? DisplayName, string? AvatarUrl);
