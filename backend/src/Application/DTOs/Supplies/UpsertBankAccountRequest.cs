namespace ChoreWars.Application.DTOs.Supplies;
public sealed record UpsertBankAccountRequest(string BankName, string AccountNumber, string AccountName, bool Active = true);
