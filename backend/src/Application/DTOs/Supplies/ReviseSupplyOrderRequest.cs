namespace ChoreWars.Application.DTOs.Supplies;
public sealed record ReviseSupplyOrderRequest(int ExpectedVersion, CreateSupplyOrderRequest Draft);
