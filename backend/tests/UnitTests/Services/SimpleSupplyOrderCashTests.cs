using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Application.Services.Supplies;
using ChoreWars.Application.Validations.Supplies;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;

namespace UnitTests.Services;

public class SimpleSupplyOrderCashTests
{
    private sealed class Mutations : IHouseMutationCoordinator
    {
        public Task RunAsync(Guid houseId, Func<Task> action, CancellationToken ct = default) => action();
        public Task<T> RunAsync<T>(Guid houseId, Func<Task<T>> action, CancellationToken ct = default) => action();
    }

    [Theory]
    [InlineData(SupplyOrderWorkflow.SIMPLE_SMS)]
    [InlineData(SupplyOrderWorkflow.SIMPLE_CONTACT)]
    public async Task CashCompletesPendingCheckoutAndRetryDoesNotDuplicateDebts(SupplyOrderWorkflow workflow)
    {
        var actor = Guid.NewGuid();
        var order = new SupplyOrder
        {
            Id = Guid.NewGuid(), HouseId = Guid.NewGuid(), CreatorUserId = actor,
            PayerUserId = actor, Workflow = workflow, Status = SupplyOrderStatus.DRAFT, Total = 10000,
            Shares = [new() { UserId = actor, Amount = 5000 }, new() { UserId = Guid.NewGuid(), Amount = 5000 }]
        };
        var payment = new SupplierPayment { Id = Guid.NewGuid(), OrderId = order.Id, Status = SupplierPaymentStatus.PENDING, Amount = order.Total };
        var store = new Mock<ISupplyRepository>();
        store.Setup(x => x.OrderAsync(order.Id, It.IsAny<CancellationToken>())).ReturnsAsync(order);
        store.Setup(x => x.PaymentsAsync(order.Id, It.IsAny<CancellationToken>())).ReturnsAsync([payment]);
        var uow = new Mock<IUnitOfWork> { DefaultValue = DefaultValue.Mock };
        var service = new SimpleSupplyOrderService(store.Object, uow.Object, Mock.Of<IHouseAccessService>(),
            new Mutations(), TimeProvider.System, new SendSupplyOrderRequestValidator(), new RecordSupplyOrderPaymentRequestValidator());
        var request = new RecordSupplyOrderPaymentRequest(Guid.NewGuid(), order.Total, "CASH:CW-test");

        await Assert.ThrowsAsync<ConflictException>(() => service.RecordPaymentAsync(order.HouseId, order.Id, actor, request with { Amount = 5000 }, default));
        Assert.Equal(SupplierPaymentStatus.PENDING, payment.Status);
        var result = await service.RecordPaymentAsync(order.HouseId, order.Id, actor, request, default);
        Assert.Equal("PAID", result.Status);
        Assert.Equal(SupplierPaymentStatus.EXPIRED, payment.Status);
        Assert.Equal(request.Reference, order.PaymentReference);
        Assert.NotNull(order.PaidAt);

        await service.RecordPaymentAsync(order.HouseId, order.Id, actor, request, default);
        uow.Verify(x => x.PaymentObligations.AddAsync(It.Is<PaymentObligation>(p =>
            p.SourceOrderId == order.Id && p.Amount == 5000 && p.CreditorUserId == actor), It.IsAny<CancellationToken>()), Times.Once);
    }
}
