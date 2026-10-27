using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class Supplier {
public Guid Id { get; set; }
public Guid OperatorUserId { get; set; }
public string Name { get; set; } = "";
public string Phone { get; set; } = "";
public string Email { get; set; } = "";
public string DeliveryArea { get; set; } = "";
public decimal DeliveryFee { get; set; }
public bool Active { get; set; } = true;
}
