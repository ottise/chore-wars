using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class SupplyOrderLine {
public Guid Id { get; set; }
public Guid OrderId { get; set; }
public Guid ProductId { get; set; }
public string Name { get; set; } = "";
public string Unit { get; set; } = "";
public decimal UnitPrice { get; set; }
public int Quantity { get; set; }
}
