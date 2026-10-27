namespace ChoreWars.Application.DTOs.Supplies;
public sealed record BankAccountResponse(Guid Id, string BankName, string AccountNumber, string AccountName, bool Active, int Version, string Verification = "SELF_DECLARED");
