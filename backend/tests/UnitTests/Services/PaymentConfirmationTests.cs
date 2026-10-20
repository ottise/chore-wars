using AutoMapper;
using ChoreWars.Application.Interfaces;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using Moq;
namespace UnitTests.Services;
public class PaymentConfirmationTests {
    private static (BountyService Service,Mock<IUnitOfWork> Uow,PaymentObligation Payment) Setup(PaymentObligationStatus status=PaymentObligationStatus.PENDING) {
        var payment = new PaymentObligation { Id=Guid.NewGuid(), HouseId=Guid.NewGuid(), DebtorUserId=Guid.NewGuid(), CreditorUserId=Guid.NewGuid(),Status=status };
        var uow=new Mock<IUnitOfWork>();
        uow.Setup(x=>x.PaymentObligations.GetByIdAsync(payment.Id,It.IsAny<CancellationToken>())).ReturnsAsync(payment);
        uow.Setup(x=>x.HouseMembers.GetByHouseAndUserIdAsync(payment.HouseId,payment.CreditorUserId,It.IsAny<CancellationToken>())).ReturnsAsync(new HouseMember{Status=HouseMemberStatus.ACTIVE});
        return(new(uow.Object,Mock.Of<IMapper>(),Mock.Of<IEventPublisher>()),uow,payment);
    }
    [Fact] public async Task DebtorCannotConfirmOwnPayment() {
        var f=Setup();await Assert.ThrowsAsync<ForbiddenException>(()=>f.Service.SettlePaymentAsync(f.Payment.Id,f.Payment.DebtorUserId));
        Assert.Equal(PaymentObligationStatus.PENDING,f.Payment.Status);
        f.Uow.Verify(x=>x.SaveChangesAsync(It.IsAny<CancellationToken>()),Times.Never);
    }
    [Fact] public async Task CreditorRetryIsIdempotent() {
        var f=Setup(PaymentObligationStatus.PAID);await f.Service.SettlePaymentAsync(f.Payment.Id,f.Payment.CreditorUserId);
        f.Uow.Verify(x=>x.SaveChangesAsync(It.IsAny<CancellationToken>()),Times.Never);
    }
    [Fact] public async Task InactiveCreditorCannotConfirm() {
        var f=Setup();f.Uow.Setup(x=>x.HouseMembers.GetByHouseAndUserIdAsync(f.Payment.HouseId,f.Payment.CreditorUserId,It.IsAny<CancellationToken>())).ReturnsAsync(new HouseMember{Status=HouseMemberStatus.LEFT});
        await Assert.ThrowsAsync<ForbiddenException>(()=>f.Service.SettlePaymentAsync(f.Payment.Id,f.Payment.CreditorUserId));
    }
    [Fact] public async Task ForcedCompensationRequiresCompletionByBeneficiary() {
        var f=Setup();f.Payment.Reason=PaymentObligationReason.FORCED_REASSIGNMENT;f.Payment.OccurrenceId=Guid.NewGuid();
        f.Uow.Setup(x=>x.ChoreOccurrences.GetByIdAsync(f.Payment.OccurrenceId.Value,It.IsAny<CancellationToken>())).ReturnsAsync(new ChoreOccurrence{Status=ChoreOccurrenceStatus.ASSIGNED,AssignedUserId=f.Payment.CreditorUserId});
        await Assert.ThrowsAsync<ConflictException>(()=>f.Service.SettlePaymentAsync(f.Payment.Id,f.Payment.CreditorUserId));
    }
}
