using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Events;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Exceptions;
using FluentValidation;
namespace ChoreWars.Application.Services.Supplies;
public sealed class SupplyCatalogService(ISupplyRepository store, ISupplierOperatorAccess operators,
    IHouseMutationCoordinator mutations, IEventPublisher events, IValidator<UpsertSupplierRequest> supplierValidator,
    IValidator<UpsertSupplyProductRequest> productValidator) : ISupplyCatalogService
{
    public static SupplierResponse Map(Supplier s) => new(s.Id,s.Name,s.Phone,s.Email,s.DeliveryArea,s.DeliveryFee);
    private static SupplyProductResponse Product(SupplyProduct p) => new(p.Id,p.SupplierId,p.Sku,p.Name,p.Unit,p.Price,p.AvailableQuantity,p.Active,p.Version);
    public async Task<List<SupplierResponse>> SuppliersAsync(CancellationToken ct) => (await store.SuppliersAsync(ct)).Select(Map).ToList();
    public async Task<SupplierResponse?> OwnAsync(Guid actor,CancellationToken ct) { var s=await store.OperatorAsync(actor,ct); return s == null ? null : Map(s); }
    public Task<bool> CanOperateAsync(Guid actor,CancellationToken ct) => Task.FromResult(operators.CanOperate(actor));
    public async Task<SupplierResponse> SaveAsync(Guid actor,UpsertSupplierRequest r,CancellationToken ct)
    {
        if(!operators.CanOperate(actor)) throw new ForbiddenException("Supplier access must be configured by the server operator.");
        await supplierValidator.ValidateAndThrowAsync(r,ct);
        return await mutations.RunAsync(actor,async()=> {
            var s=await store.OperatorAsync(actor,ct);
            if(s==null) { s=new Supplier{Id=Guid.NewGuid(),OperatorUserId=actor};store.Add(s); }
            s.Name=r.Name.Trim();s.Phone=r.Phone?.Trim()??"";s.Email=r.Email?.Trim()??"";s.DeliveryArea=r.DeliveryArea.Trim();s.DeliveryFee=r.DeliveryFee;
            return Map(s);
        },ct);
    }
    public async Task<List<SupplyProductResponse>> ProductsAsync(Guid supplier,bool includeInactive,Guid actor,CancellationToken ct)
    {
        var s=await store.SupplierAsync(supplier,ct)??throw new NotFoundException("Supplier not found.");
        if(includeInactive && s.OperatorUserId!=actor) throw new ForbiddenException();
        return (await store.ProductsAsync(supplier,ct)).Where(x=>includeInactive||x.Active).Select(Product).ToList();
    }
    public async Task<SupplyProductResponse> SaveProductAsync(Guid actor,Guid id,UpsertSupplyProductRequest r,CancellationToken ct)
    {
        await productValidator.ValidateAndThrowAsync(r,ct);
        var owner=await store.OperatorAsync(actor,ct)??throw new ForbiddenException();
        return await mutations.RunAsync(owner.Id,async()=> {
            var p=id==Guid.Empty?null:await store.ProductAsync(id,ct);
            var sameSku=(await store.ProductsAsync(owner.Id,ct)).SingleOrDefault(x=>x.Sku==r.Sku.Trim()&&x.Id!=id);
            if(sameSku!=null){
                if(id==Guid.Empty && sameSku.Name==r.Name.Trim() && sameSku.Unit==r.Unit.Trim() && sameSku.Price==r.Price && sameSku.AvailableQuantity==r.AvailableQuantity && sameSku.Active==r.Active)return Product(sameSku);
                throw new ConflictException("This SKU is already in use. Edit the existing product instead.");
            }
            if(id!=Guid.Empty && p==null)throw new NotFoundException("Product not found.");
            if(p!=null && p.SupplierId!=owner.Id)throw new ForbiddenException();
            if(p!=null && p.Version!=r.ExpectedVersion)throw new ConflictException("Product stock or price changed. Refresh before editing.");
            if(p==null){p=new SupplyProduct{Id=Guid.NewGuid(),SupplierId=owner.Id};store.Add(p);}
            p.Sku=r.Sku.Trim();p.Name=r.Name.Trim();p.Unit=r.Unit.Trim();p.Price=r.Price;p.AvailableQuantity=r.AvailableQuantity;p.Active=r.Active;
            return Product(p);
        },ct);
    }
    private static SupplierOrderResponse SupplierOrder(SupplyOrder o) => new(o.Id,o.Status.ToString(),o.Version,o.DeliveryAddress,o.ContactPhone,o.Total,o.RefundedAmount,o.CreatedAt,
        o.Lines.Select(x=>new SupplyOrderLineResponse(x.ProductId,x.Name,x.Unit,x.UnitPrice,x.Quantity)).ToList());
    public async Task<List<SupplierOrderResponse>> OrdersAsync(Guid actor,CancellationToken ct)
    {
        var s=await store.OperatorAsync(actor,ct)??throw new ForbiddenException();
        return (await store.OrdersAsync(null,s.Id,ct)).Where(x=>x.PaidAt!=null).Select(SupplierOrder).ToList();
    }
    public async Task<SupplierOrderResponse> FulfillAsync(Guid actor,Guid id,string status,int version,CancellationToken ct)
    {
        var probe=await store.OrderAsync(id,ct)??throw new NotFoundException("Purchase not found.");
        return await mutations.RunAsync(probe.HouseId,async()=> {
            var o=await store.OrderAsync(id,ct)??throw new NotFoundException("Purchase not found.");
            var s=await store.SupplierAsync(o.SupplierId,ct)??throw new NotFoundException("Supplier not found.");
            if(s.OperatorUserId!=actor)throw new ForbiddenException();
            SupplyOrderService.CheckVersion(o,version);
            var next=status==nameof(SupplyOrderStatus.FULFILLING)?SupplyOrderStatus.FULFILLING:
                status==nameof(SupplyOrderStatus.DELIVERED)?SupplyOrderStatus.DELIVERED:throw new DomainException("Choose FULFILLING or DELIVERED.");
            if(!((o.Status==SupplyOrderStatus.PAID && next==SupplyOrderStatus.FULFILLING)||(o.Status==SupplyOrderStatus.FULFILLING&&next==SupplyOrderStatus.DELIVERED)))
                throw new ConflictException("Invalid delivery transition.");
            o.Status=next;o.Version++;
            await events.PublishAsync(new SupplyNotificationEvent(o.HouseId,o.Id,SupplyConstants.OrderTarget,actor,null,"Delivery updated",$"Your purchase is now {next.ToString().ToLowerInvariant()}.") ,ct);
            return SupplierOrder(o);
        },ct);
    }
}
