using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class SupplyProduct {
public Guid Id { get; set; }
public uint Version { get; set; }
public Guid SupplierId { get; set; }
public string Sku { get; set; } = "";
public string Name { get; set; } = "";
public string Unit { get; set; } = "";
public decimal Price { get; set; }
public int AvailableQuantity { get; set; }
public bool Active { get; set; } = true;
}
