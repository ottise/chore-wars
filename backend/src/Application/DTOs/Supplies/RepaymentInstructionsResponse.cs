namespace ChoreWars.Application.DTOs.Supplies;
public sealed record RepaymentInstructionsResponse(Guid CreditorUserId, string CreditorName, decimal RemainingAmount, string Reference, BankAccountResponse? BankAccount);
