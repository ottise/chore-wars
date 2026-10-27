using System.Security.Claims;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace ChoreWars.Presentation.Controllers;
[ApiController,Authorize]
public sealed class SupplierCatalogController(ISupplyCatalogService service):ControllerBase {
private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());

[HttpGet("api/suppliers")] public async Task<IActionResult> List(CancellationToken ct)=>Ok(await service.SuppliersAsync(ct));
[HttpGet("api/supplier/profile")] public async Task<IActionResult> Own(CancellationToken ct)=>Ok(new{canOperate=await service.CanOperateAsync(Actor,ct),supplier=await service.OwnAsync(Actor,ct)});
[HttpPut("api/supplier/profile")] public async Task<IActionResult> Save(UpsertSupplierRequest r,CancellationToken ct)=>Ok(await service.SaveAsync(Actor,r,ct));
[HttpGet("api/suppliers/{supplierId:guid}/products")] public async Task<IActionResult> Products(Guid supplierId,[FromQuery]bool includeInactive,CancellationToken ct)=>Ok(await service.ProductsAsync(supplierId,includeInactive,Actor,ct));
[HttpPost("api/supplier/products")] public async Task<IActionResult> CreateProduct(UpsertSupplyProductRequest r,CancellationToken ct)=>Ok(await service.SaveProductAsync(Actor,Guid.Empty,r,ct));
[HttpPut("api/supplier/products/{productId:guid}")] public async Task<IActionResult> SaveProduct(Guid productId,UpsertSupplyProductRequest r,CancellationToken ct)=>Ok(await service.SaveProductAsync(Actor,productId,r,ct));

}
