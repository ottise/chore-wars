using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;

namespace IntegrationTests.Infrastructure;

public class SimpleOrderCalendarTests
{
    private static Task<PostgresFixture> Fixture(bool configured = true) => PostgresFixture.CreateAsync(configure: services =>
    {
        var sender = new Mock<ISupplyOrderEmailSender>(); sender.SetupGet(x => x.IsConfigured).Returns(configured);
        services.AddScoped(_ => sender.Object);
    });
    private static async Task<(Guid Supplier, Guid Product)> Catalog(PostgresFixture f, Guid actor)
    {
        await using var scope = f.Services.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var supplier = new Supplier { Id = Guid.NewGuid(), OperatorUserId = actor, Name = "Test contact", Email = "supplier@example.test", Phone = "0123456789" };
        var product = new SupplyProduct { Id = Guid.NewGuid(), SupplierId = supplier.Id, Name = "Rice", Unit = "bag", Sku = "test-rice", Price = 1000, AvailableQuantity = 10 };
        db.Add(supplier); db.Add(product); await db.SaveChangesAsync(); return (supplier.Id, product.Id);
    }

    [PostgresFact]
    public async Task SendDefaultsToPayerShareAndManualPaymentCannotConfirmAnOrder()
    {
        await using var f = await Fixture(); var seed = await CoreConcurrencyTests.Seed(f); var catalog = await Catalog(f, seed.Users[0]);
        var request = new SendSupplyOrderRequest(Guid.NewGuid(), catalog.Supplier, [new(catalog.Product, 2)]);
        await using var scope = f.Services.CreateAsyncScope(); var service = scope.ServiceProvider.GetRequiredService<ISimpleSupplyOrderService>();
        var first = await service.SendAsync(seed.HouseId, seed.Users[0], request, default);
        Assert.Equal(first.Id, (await service.SendAsync(seed.HouseId, seed.Users[0], request, default)).Id);
        Assert.Single(first.Shares); Assert.Equal(seed.Users[0], first.Shares[0].UserId); Assert.Equal(2000, first.Shares[0].Amount); Assert.Equal("NOT_REQUESTED", first.EmailStatus);
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Single(await db.SupplyOrders.ToListAsync()); Assert.Empty(await db.SupplyOrderEmailDispatches.ToListAsync());
        Assert.Empty(await db.ActionProposals.ToListAsync()); Assert.Empty(await db.PaymentObligations.ToListAsync());
        var payment = new RecordSupplyOrderPaymentRequest(Guid.NewGuid(), 2000, "bank reference");
        await Assert.ThrowsAsync<ForbiddenException>(() => service.RecordPaymentAsync(seed.HouseId, first.Id, seed.Users[1], payment, default));
        await Assert.ThrowsAsync<ConflictException>(() => service.RecordPaymentAsync(seed.HouseId, first.Id, seed.Users[0], payment, default));
        Assert.Equal("DRAFT", (await service.SendAsync(seed.HouseId, seed.Users[0], request, default)).Status);
        Assert.Empty(await db.PaymentObligations.ToListAsync());
        Assert.Single(await db.SupplyOrderActivities.Where(a => a.Kind == "SMS_PREPARED").ToListAsync());
        Assert.Empty(await db.SupplyOrderActivities.Where(a => a.Kind == OrderEmailState.UserReported).ToListAsync());
        await Assert.ThrowsAsync<ConflictException>(() => service.SendAsync(seed.HouseId, seed.Users[0], request with { Lines = [new(catalog.Product, 3)] }, default));
    }

    [PostgresFact]
    public async Task SmsOrderDoesNotDependOnEmailConfiguration()
    {
        await using var f = await Fixture(false); var seed = await CoreConcurrencyTests.Seed(f); var catalog = await Catalog(f, seed.Users[0]);
        await using var scope = f.Services.CreateAsyncScope();
        var order = await scope.ServiceProvider.GetRequiredService<ISimpleSupplyOrderService>().SendAsync(seed.HouseId, seed.Users[0], new(Guid.NewGuid(), catalog.Supplier, [new(catalog.Product, 1)]), default);
        Assert.Equal("SIMPLE_SMS", order.Workflow);
        Assert.Single(await scope.ServiceProvider.GetRequiredService<AppDbContext>().SupplyOrders.ToListAsync());
        Assert.Empty(await scope.ServiceProvider.GetRequiredService<AppDbContext>().SupplyOrderEmailDispatches.ToListAsync());
    }

    [PostgresFact]
    public async Task ExpiredEmailLeaseRequiresExplicitRetryAndNeverClaimsSuccess()
    {
        await using var f = await Fixture(); var seed = await CoreConcurrencyTests.Seed(f); var catalog = await Catalog(f, seed.Users[0]);
        await using var scope = f.Services.CreateAsyncScope(); var service = scope.ServiceProvider.GetRequiredService<ISimpleSupplyOrderService>();
        var order = await service.SendAsync(seed.HouseId, seed.Users[0], new(Guid.NewGuid(), catalog.Supplier, [new(catalog.Product, 1)]), default);
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var legacy = await context.SupplyOrders.SingleAsync();
        legacy.Workflow = SupplyOrderWorkflow.SIMPLE_CONTACT;
        legacy.EmailDispatch = new() { Id = Guid.NewGuid(), OrderId = legacy.Id, Recipient = "legacy@example.test", Subject = "Old order", Body = "Archived request", CreatedAt = DateTime.UtcNow };
        context.SupplyOrderEmailDispatches.Add(legacy.EmailDispatch);
        await context.SaveChangesAsync();
        var store = scope.ServiceProvider.GetRequiredService<ISupplyRepository>();
        var now = DateTime.UtcNow; Assert.NotNull(await store.ClaimEmailAsync(now, default));
        Assert.Null(await store.ClaimEmailAsync(now.AddMinutes(3), default));
        Assert.Equal(OrderEmailState.Unknown, (await store.OrderAsync(order.Id, default))!.EmailDispatch!.State);
        Assert.Null(await store.ClaimEmailAsync(now.AddMinutes(4), default));
        await Assert.ThrowsAsync<ConflictException>(() => service.RetryEmailAsync(seed.HouseId, order.Id, seed.Users[0], default));
        Assert.Null(await store.ClaimEmailAsync(now.AddMinutes(4), default));
    }

    [PostgresFact]
    public async Task CalendarUsesVietnamCompletionDayAndNeverExposesDraftEvidence()
    {
        await using var f = await Fixture(); var seed = await CoreConcurrencyTests.Seed(f);
        await using var scope = f.Services.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var occurrence = await db.ChoreOccurrences.SingleAsync(); var day = new DateOnly(2026, 10, 28);
        occurrence.DueDate = ScheduleTime.Utc(day.AddDays(-1), 1200); occurrence.CompletedAt = ScheduleTime.Utc(day, 5);
        occurrence.CompletedByUserId = seed.Users[1]; occurrence.Status = ChoreOccurrenceStatus.COMPLETED;
        for (var i = 0; i < 4; i++) db.ChoreEvidence.Add(new() { Id = Guid.NewGuid(), HouseId = seed.HouseId, OccurrenceId = occurrence.Id,
            UploadedByUserId = seed.Users[0], ClientRequestId = Guid.NewGuid(), CreatedAt = DateTime.UtcNow,
            AttachedAt = i < 3 ? DateTime.UtcNow : null, StorageKey = "test-only", ContentHash = "test" });
        await db.SaveChangesAsync();
        var service = scope.ServiceProvider.GetRequiredService<IHouseCalendarService>();
        var result = await service.ReadAsync(seed.HouseId, seed.Users[0], day.AddDays(-1), day, default);
        Assert.Equal(0, result.Days[0].TotalEvidenceCount); Assert.Equal(1, result.Days[0].ScheduledCount);
        Assert.Equal(3, result.Days[1].TotalEvidenceCount); Assert.Equal(2, result.Days[1].PreviewEvidenceIds.Count);
        Assert.Equal(seed.Users[1], Assert.Single(result.Days[1].Items).CompletedByUserId);
        await Assert.ThrowsAsync<ForbiddenException>(() => service.ReadAsync(seed.HouseId, Guid.NewGuid(), day, day, default));
        await Assert.ThrowsAsync<DomainException>(() => service.ReadAsync(seed.HouseId, seed.Users[0], day, day.AddDays(42), default));
    }
}
