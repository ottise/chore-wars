using AutoMapper;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using Moq;

namespace UnitTests.Services;

public class PaymentObligationTests
{
    [Fact]
    public async Task SettlePaymentAsync_ShouldSetPaidStatusAndPaidAt()
    {
        var userId = Guid.NewGuid();
        var payment = new PaymentObligation
        {
            Id = Guid.NewGuid(),
            DebtorUserId = userId,
            CreditorUserId = Guid.NewGuid(),
            Status = PaymentObligationStatus.PENDING
        };
        var unitOfWork = new Mock<IUnitOfWork>();
        var payments = new Mock<IPaymentObligationRepository>();
        unitOfWork.SetupGet(x => x.PaymentObligations).Returns(payments.Object);
        payments.Setup(x => x.GetByIdAsync(payment.Id, It.IsAny<CancellationToken>())).ReturnsAsync(payment);
        unitOfWork.Setup(x => x.BeginTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(x => x.CommitTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(x => x.RollbackTransactionAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        unitOfWork.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);
        var service = new BountyService(unitOfWork.Object, Mock.Of<IMapper>(), Mock.Of<IEventPublisher>());

        await service.SettlePaymentAsync(payment.Id, userId);

        Assert.Equal(PaymentObligationStatus.PAID, payment.Status);
        Assert.NotNull(payment.PaidAt);
        payments.Verify(x => x.Update(payment), Times.Once);
        unitOfWork.Verify(x => x.CommitTransactionAsync(It.IsAny<CancellationToken>()), Times.Once);
    }
}
