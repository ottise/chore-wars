using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class UserBankAccount {
public Guid Id { get; set; }
public Guid UserId { get; set; }
public string BankName { get; set; } = "";
public string AccountNumber { get; set; } = "";
public string AccountName { get; set; } = "";
public int Version { get; set; } = 1;
public bool Active { get; set; } = true;
}
