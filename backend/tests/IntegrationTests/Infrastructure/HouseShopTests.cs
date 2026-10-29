using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;

namespace IntegrationTests.Infrastructure;

public sealed class HouseShopTests
{
    [PostgresFact]
    public async Task MembersAddPrivateContactsRetryWithoutDuplicatesAndCannotUseAnotherHouseCatalog()
    {
        await using var f = await PostgresFixture.CreateAsync(configure: services => {
            var sender = new Mock<ISupplyOrderEmailSender>(); sender.SetupGet(x => x.IsConfigured).Returns(true);
            services.AddScoped(_ => sender.Object);
        });
        var a = await CoreConcurrencyTests.Seed(f); var b = await CoreConcurrencyTests.Seed(f);
        await using var scope = f.Services.CreateAsyncScope();
        var service = scope.ServiceProvider.GetRequiredService<ISupplyCatalogService>();
        var request = new CreateShopItemRequest(Guid.NewGuid(), "ST25 rice", "5 kg bag", 150000, "Rice shop", "+84901234567", "rice@example.test");
        var item = await service.CreateShopItemAsync(a.HouseId, a.Users[1], request, default);
        var retry = await service.CreateShopItemAsync(a.HouseId, a.Users[1], request, default);
        Assert.Equal(item.Product.Id, retry.Product.Id);
        Assert.Single(await service.HouseSuppliersAsync(a.HouseId, a.Users[2], default));
        Assert.Empty(await service.HouseSuppliersAsync(b.HouseId, b.Users[0], default));
        Assert.Empty(await service.SuppliersAsync(default));
        Assert.Single(await service.ProductsAsync(item.Supplier.Id, false, a.Users[0], default));
        await Assert.ThrowsAsync<ForbiddenException>(() => service.ProductsAsync(item.Supplier.Id, false, b.Users[0], default));
        await Assert.ThrowsAsync<ForbiddenException>(() => service.HouseSuppliersAsync(a.HouseId, b.Users[0], default));
        await Assert.ThrowsAsync<ForbiddenException>(() => service.CreateShopItemAsync(a.HouseId, b.Users[0], request with { ClientRequestId = Guid.NewGuid() }, default));
        await Assert.ThrowsAsync<ConflictException>(() => service.CreateShopItemAsync(a.HouseId, a.Users[1], request with { Price = 200000 }, default));
        var orders = scope.ServiceProvider.GetRequiredService<ISimpleSupplyOrderService>();
        await Assert.ThrowsAsync<NotFoundException>(() => orders.SendAsync(b.HouseId, b.Users[0], new(Guid.NewGuid(), item.Supplier.Id, [new(item.Product.Id, 1)]), default));
        var sent = await orders.SendAsync(a.HouseId, a.Users[1], new(Guid.NewGuid(), item.Supplier.Id, [new(item.Product.Id, 2)]), default);
        Assert.Equal(300000, sent.Total);
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Null((await db.Suppliers.SingleAsync()).OperatorUserId);
        Assert.Single(await db.SupplyProducts.ToListAsync());
        Assert.Empty(await db.SupplyOrderEmailDispatches.ToListAsync());
    }

    [PostgresFact]
    public async Task PhoneOnlyItemsSaveButCannotPretendToSendEmail()
    {
        await using var f = await PostgresFixture.CreateAsync(); var seed = await CoreConcurrencyTests.Seed(f);
        await using var scope = f.Services.CreateAsyncScope();
        var service = scope.ServiceProvider.GetRequiredService<ISupplyCatalogService>();
        var item = await service.CreateShopItemAsync(seed.HouseId, seed.Users[0], new(Guid.NewGuid(), "Water", "bottle", 20000, "Water shop", "0901234567", ""), default);
        var order = await scope.ServiceProvider.GetRequiredService<ISimpleSupplyOrderService>().SendAsync(seed.HouseId, seed.Users[0], new(Guid.NewGuid(), item.Supplier.Id, [new(item.Product.Id, 1)]), default);
        Assert.Equal("SIMPLE_SMS", order.Workflow);
        Assert.Empty(await scope.ServiceProvider.GetRequiredService<AppDbContext>().SupplyOrderEmailDispatches.ToListAsync());
        await service.CreateShopItemAsync(seed.HouseId, seed.Users[0], new(Guid.NewGuid(), "Rice", "bag", 150000, "Rice shop", "0901234567", "rice@example.test"), default);
        Assert.Equal(2, (await service.HouseSuppliersAsync(seed.HouseId, seed.Users[1], default)).Count);
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        (await db.Houses.SingleAsync()).IsArchived = true; await db.SaveChangesAsync();
        await Assert.ThrowsAsync<ConflictException>(() => service.CreateShopItemAsync(seed.HouseId, seed.Users[0], new(Guid.NewGuid(), "Salt", "bag", 10000, "Shop", "0901234567", ""), default));
    }
}
