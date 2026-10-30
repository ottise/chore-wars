using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace IntegrationTests.Infrastructure;
public sealed class SupplyPurchaseTests
{
 private sealed class Gateway:IPurchasePaymentGateway {
  public SupplierCheckoutRequest? Request;public bool Paid;
  public void EnsureConfigured(){}
  public Task<SupplierCheckoutResult>CreateAsync(SupplierCheckoutRequest r,CancellationToken ct){Request=r;return Task.FromResult(new SupplierCheckoutResult("test-link","https://pay.payos.vn/test","test-qr"));}
  public Task<SupplierPaymentResult>QueryAsync(long code,CancellationToken ct)=>Task.FromResult(new SupplierPaymentResult(code,Paid?"PAID":"PENDING",Request!.Amount,"test-link","test-bank-reference"));
  public Task<SupplierPaymentResult>VerifyAsync(JsonElement payload,CancellationToken ct)=>QueryAsync(Request!.OrderCode,ct);
 }
 private sealed record Seed(Guid House,Guid A,Guid B,Guid C,Guid SupplierActor,Guid Supplier,Guid Product);
 private static async Task<Seed> Data(PostgresFixture f){await using var scope=f.Services.CreateAsyncScope();var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
  var users=Enumerable.Range(0,4).Select(i=>new User{Id=Guid.NewGuid(),Email=$"{Guid.NewGuid()}@test.example",DisplayName=$"Person {i}",PasswordHash="test",CreatedAt=DateTime.UtcNow}).ToArray();db.Users.AddRange(users);
  var h=new House{Id=Guid.NewGuid(),Name="Supply test",InviteCode=Guid.NewGuid().ToString("N")[..8],CreatedAt=DateTime.UtcNow};db.Houses.Add(h);
  db.HouseMembers.AddRange(users.Take(3).Select((u,i)=>new HouseMember{Id=Guid.NewGuid(),HouseId=h.Id,UserId=u.Id,Role=i==0?HouseRole.OWNER:HouseRole.MEMBER,Status=HouseMemberStatus.ACTIVE,JoinedAt=DateTime.UtcNow}));
  var s=new Supplier{Id=Guid.NewGuid(),OperatorUserId=users[3].Id,Name="Test supplier",Phone="0123456789",Email="supplier@example.test",DeliveryArea="Test area"};db.Suppliers.Add(s);
  var p=new SupplyProduct{Id=Guid.NewGuid(),SupplierId=s.Id,Sku="RICE",Name="Rice",Unit="bag",Price=360000,AvailableQuantity=10};db.SupplyProducts.Add(p);await db.SaveChangesAsync();return new(h.Id,users[0].Id,users[1].Id,users[2].Id,users[3].Id,s.Id,p.Id);
 }
 private static async Task<T> Call<S,T>(PostgresFixture f,Func<S,Task<T>> fn)where S:notnull{await using var scope=f.Services.CreateAsyncScope();return await fn(scope.ServiceProvider.GetRequiredService<S>());}
 private static async Task<SupplyOrderResponse> Buy(PostgresFixture f,Seed s,Gateway gateway){
  var r=new CreateSupplyOrderRequest(Guid.NewGuid(),s.Supplier,s.A,"Test delivery address","0123456789",[new(s.Product,1)],[new(s.A),new(s.B),new(s.C)]);
  var o=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.CreateAsync(s.House,s.A,r,default));
  var duplicate=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.CreateAsync(s.House,s.A,r,default));Assert.Equal(o.Id,duplicate.Id);
  await Assert.ThrowsAsync<ForbiddenException>(()=>Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.ReadAsync(s.House,o.Id,s.SupplierActor,default)));
  o=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.SubmitAsync(s.House,o.Id,s.A,o.Version,default));
  foreach(var user in new[]{s.A,s.B,s.C}){var current=o;o=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.DecideAsync(s.House,current.Id,user,new(current.Version,true),default));}
  var approved=o;
  await Assert.ThrowsAsync<ForbiddenException>(()=>Call<ISupplierPaymentService,SupplierCheckoutResponse>(f,x=>x.CheckoutAsync(s.House,approved.Id,s.B,approved.Version,default)));
  await Call<ISupplierPaymentService,SupplierCheckoutResponse>(f,x=>x.CheckoutAsync(s.House,approved.Id,s.A,approved.Version,default));
  gateway.Paid=true;
  await Call<ISupplierPaymentService,SupplierCheckoutResponse?>(f,x=>x.RefreshAsync(s.House,approved.Id,s.A,default));
  await Call<ISupplierPaymentService,SupplierCheckoutResponse?>(f,x=>x.RefreshAsync(s.House,approved.Id,s.A,default));
  return await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.ReadAsync(s.House,approved.Id,s.A,default));
 }
 [PostgresFact]public async Task PaymentCreatesDirectDebtsOnceAndCreditorConfirmsPartialTransfers(){
  var gateway=new Gateway();await using var f=await PostgresFixture.CreateAsync(configure:s=>s.AddSingleton<IPurchasePaymentGateway>(gateway));var seed=await Data(f);var order=await Buy(f,seed,gateway);Assert.Equal("PAID",order.Status);
  var summary=await Call<IInternalRepaymentService,PurchaseDebtSummaryResponse>(f,x=>x.SummaryAsync(seed.House,seed.A,default));Assert.Equal(2,summary.Debts.Count);Assert.Equal(240000,summary.OwedToMe);Assert.Equal(120000,summary.PersonalCost);
  var debt=summary.Debts.Single(x=>x.DebtorUserId==seed.B);var report=new ReportRepaymentRequest(Guid.NewGuid(),50000,"bank receipt one");
  await Assert.ThrowsAsync<ForbiddenException>(()=>Call<IInternalRepaymentService,PurchaseDebtResponse>(f,x=>x.ReportAsync(debt.Id,seed.C,report,default)));
  var pending=await Call<IInternalRepaymentService,PurchaseDebtResponse>(f,x=>x.ReportAsync(debt.Id,seed.B,report,default));Assert.Equal(120000,pending.RemainingAmount);var transfer=Assert.Single(pending.Repayments);
  await Assert.ThrowsAsync<ForbiddenException>(()=>Call<IInternalRepaymentService,PurchaseDebtResponse>(f,x=>x.RespondAsync(debt.Id,transfer.Id,seed.B,new(true),default)));
  var received=await Call<IInternalRepaymentService,PurchaseDebtResponse>(f,x=>x.RespondAsync(debt.Id,transfer.Id,seed.A,new(true),default));Assert.Equal(70000,received.RemainingAmount);
  received=await Call<IInternalRepaymentService,PurchaseDebtResponse>(f,x=>x.RespondAsync(debt.Id,transfer.Id,seed.A,new(true),default));Assert.Equal(70000,received.RemainingAmount);
  await Assert.ThrowsAsync<ConflictException>(async()=>{await using var scope=f.Services.CreateAsyncScope();await scope.ServiceProvider.GetRequiredService<IBountyService>().SettlePaymentAsync(debt.Id,seed.A);});
  await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();Assert.Equal(2,await db.PaymentObligations.CountAsync());Assert.Equal(1,await db.PaymentWebhookReceipts.CountAsync());Assert.Equal(9,(await db.SupplyProducts.SingleAsync()).AvailableQuantity);
 }
 [PostgresFact]public async Task SmsOrderCanOnlyBeMarkedPaidAfterPayOSVerifiesAndCreatesOneDebtPerMember(){
  var gateway=new Gateway();await using var f=await PostgresFixture.CreateAsync(configure:s=>s.AddSingleton<IPurchasePaymentGateway>(gateway));var seed=await Data(f);
  var request=new SendSupplyOrderRequest(Guid.NewGuid(),seed.Supplier,[new(seed.Product,1)],Shares:[new(seed.A),new(seed.B),new(seed.C)]);
  var order=await Call<ISimpleSupplyOrderService,SupplyOrderResponse>(f,x=>x.SendAsync(seed.House,seed.A,request,default));
  Assert.Equal("SIMPLE_SMS",order.Workflow);Assert.Equal(3,order.Shares.Count);Assert.Equal(360000,order.Shares.Sum(s=>s.Amount));
  await Assert.ThrowsAsync<ConflictException>(()=>Call<ISimpleSupplyOrderService,SupplyOrderResponse>(f,x=>x.RecordPaymentAsync(seed.House,order.Id,seed.A,new(Guid.NewGuid(),360000,"fake"),default)));
  var checkout=await Call<ISupplierPaymentService,SupplierCheckoutResponse>(f,x=>x.CheckoutAsync(seed.House,order.Id,seed.A,order.Version,default));
  Assert.Equal("PENDING",checkout.Status);Assert.Equal("https://pay.payos.vn/test",checkout.CheckoutUrl);
  gateway.Paid=true;
  var verified=await Call<ISupplierPaymentService,SupplierCheckoutResponse?>(f,x=>x.RefreshAsync(seed.House,order.Id,seed.A,default));Assert.Equal("VERIFIED",verified!.Status);
  var paid=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.ReadAsync(seed.House,order.Id,seed.A,default));Assert.Equal("PAID",paid.Status);Assert.Equal("PAYOS_VERIFIED",paid.PaymentConfirmationSource);
  var debts=await Call<IInternalRepaymentService,PurchaseDebtSummaryResponse>(f,x=>x.SummaryAsync(seed.House,seed.A,default));
  Assert.Equal(2,debts.Debts.Count);Assert.Equal(240000,debts.OwedToMe);Assert.Equal(120000,debts.PersonalCost);
  await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();Assert.Equal(2,await db.PaymentObligations.CountAsync());
 }
 [PostgresFact]public async Task SupplierRefundAfterRepaymentCreatesReturnDebtWithoutNetting(){
  var gateway=new Gateway();await using var f=await PostgresFixture.CreateAsync(configure:s=>s.AddSingleton<IPurchasePaymentGateway>(gateway));var seed=await Data(f);var order=await Buy(f,seed,gateway);
  var debts=await Call<IInternalRepaymentService,PurchaseDebtSummaryResponse>(f,x=>x.SummaryAsync(seed.House,seed.A,default));var debt=debts.Debts.Single(x=>x.DebtorUserId==seed.B);
  var reported=await Call<IInternalRepaymentService,PurchaseDebtResponse>(f,x=>x.ReportAsync(debt.Id,seed.B,new(Guid.NewGuid(),120000,"paid in full"),default));
  await Call<IInternalRepaymentService,PurchaseDebtResponse>(f,x=>x.RespondAsync(debt.Id,reported.Repayments.Single().Id,seed.A,new(true),default));
  var refund=await Call<ISupplyRefundService,SupplierRefundResponse>(f,x=>x.ReportAsync(order.Id,seed.SupplierActor,new(Guid.NewGuid(),360000,"supplier-bank-refund","Order cancelled"),default));
  await Call<ISupplyRefundService,SupplierRefundResponse>(f,x=>x.ConfirmAsync(order.Id,refund.Id,seed.A,default));await Call<ISupplyRefundService,SupplierRefundResponse>(f,x=>x.ConfirmAsync(order.Id,refund.Id,seed.A,default));
  var summary=await Call<IInternalRepaymentService,PurchaseDebtSummaryResponse>(f,x=>x.SummaryAsync(seed.House,seed.A,default));Assert.Equal(0,summary.PersonalCost);Assert.Equal(0,summary.OwedToMe);var back=Assert.Single(summary.Debts,x=>x.DebtorUserId==seed.A);Assert.Equal(seed.B,back.CreditorUserId);Assert.Equal(120000,back.RemainingAmount);
 }
 [PostgresFact]public async Task BankDetailsAreOnlyDisclosedToTheDebtorAndRemindersAreIdempotent(){
  var gateway=new Gateway();await using var f=await PostgresFixture.CreateAsync(configure:s=>s.AddSingleton<IPurchasePaymentGateway>(gateway));var seed=await Data(f);await Buy(f,seed,gateway);
  await Call<IUserBankAccountService,BankAccountResponse>(f,x=>x.SaveAsync(seed.A,new("Test bank","123456789","Person A"),default));
  var summary=await Call<IInternalRepaymentService,PurchaseDebtSummaryResponse>(f,x=>x.SummaryAsync(seed.House,seed.A,default));var debt=summary.Debts.Single(x=>x.DebtorUserId==seed.B);
  var instructions=await Call<IInternalRepaymentService,RepaymentInstructionsResponse>(f,x=>x.InstructionsAsync(debt.Id,seed.B,default));Assert.Equal("123456789",instructions.BankAccount!.AccountNumber);
  await Assert.ThrowsAsync<ForbiddenException>(()=>Call<IInternalRepaymentService,RepaymentInstructionsResponse>(f,x=>x.InstructionsAsync(debt.Id,seed.C,default)));
  await Assert.ThrowsAsync<ForbiddenException>(()=>Call<ISupplyReminderService,SupplyScheduleResponse>(f,x=>x.CreateAsync(seed.House,seed.B,new(Guid.NewGuid(),"Rice and water",5,19,0),default)));
  var schedule=await Call<ISupplyReminderService,SupplyScheduleResponse>(f,x=>x.CreateAsync(seed.House,seed.A,new(Guid.NewGuid(),"Rice and water",5,19,0,0,0),default));
  await using(var setup=f.Services.CreateAsyncScope()){var db=setup.ServiceProvider.GetRequiredService<AppDbContext>();(await db.SupplySchedules.SingleAsync()).NextDueAt=DateTime.UtcNow.AddMinutes(-1);await db.SaveChangesAsync();}
  async Task Process(){await using var scope=f.Services.CreateAsyncScope();await scope.ServiceProvider.GetRequiredService<ISupplyReminderService>().ProcessAsync(schedule.Id,default);}
  await Task.WhenAll(Process(),Process());await using var read=f.Services.CreateAsyncScope();Assert.Equal(1,await read.ServiceProvider.GetRequiredService<AppDbContext>().SupplyReminderDeliveries.CountAsync());
 }
 [PostgresFact]public async Task RevisingAnApprovedPurchaseInvalidatesConsentAndRestoresReservedStock(){
  await using var f=await PostgresFixture.CreateAsync();var s=await Data(f);
  var request=new CreateSupplyOrderRequest(Guid.NewGuid(),s.Supplier,s.A,"First address","0123456789",[new(s.Product,1)],[new(s.A),new(s.B)]);
  var o=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.CreateAsync(s.House,s.A,request,default));
  o=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.SubmitAsync(s.House,o.Id,s.A,o.Version,default));
  foreach(var user in new[]{s.A,s.B}){var current=o;o=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.DecideAsync(s.House,current.Id,user,new(current.Version,true),default));}
  var version=o.Version;var revision=new ReviseSupplyOrderRequest(version,request with{ClientRequestId=Guid.NewGuid(),DeliveryAddress="New address",Lines=[new(s.Product,2)]});
  var updated=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.ReviseAsync(s.House,o.Id,s.A,revision,default));Assert.Equal(o.Id,updated.Id);Assert.Equal("DRAFT",updated.Status);Assert.Equal(720000,updated.Total);Assert.All(updated.Shares,share=>Assert.False(share.Approved));
  var retried=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.ReviseAsync(s.House,o.Id,s.A,revision,default));Assert.Equal(updated.Version,retried.Version);
  await using var read=f.Services.CreateAsyncScope();var db=read.ServiceProvider.GetRequiredService<AppDbContext>();Assert.Equal(10,(await db.SupplyProducts.SingleAsync()).AvailableQuantity);Assert.Equal(ProposalStatus.CANCELLED,(await db.ActionProposals.SingleAsync()).Status);Assert.Single(await db.SupplyOrderLines.ToListAsync());Assert.Equal(2,await db.OrderCostShares.CountAsync());
 }
 [PostgresFact]public async Task TwoHouseholdsCannotReserveTheLastProductTwice(){
  await using var f=await PostgresFixture.CreateAsync();var s=await Data(f);var second=Guid.NewGuid();
  await using(var setup=f.Services.CreateAsyncScope()){var db=setup.ServiceProvider.GetRequiredService<AppDbContext>();db.Houses.Add(new House{Id=second,Name="Second house",InviteCode="STOCK222",CreatedAt=DateTime.UtcNow});db.HouseMembers.Add(new HouseMember{Id=Guid.NewGuid(),HouseId=second,UserId=s.B,Role=HouseRole.OWNER,Status=HouseMemberStatus.ACTIVE,JoinedAt=DateTime.UtcNow});(await db.SupplyProducts.SingleAsync()).AvailableQuantity=1;await db.SaveChangesAsync();}
  async Task<SupplyOrderResponse> Draft(Guid house,Guid user){var r=new CreateSupplyOrderRequest(Guid.NewGuid(),s.Supplier,user,"Test address","0123456789",[new(s.Product,1)],[new(user)]);var o=await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.CreateAsync(house,user,r,default));return await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.SubmitAsync(house,o.Id,user,o.Version,default));}
  var a=await Draft(s.House,s.A);var b=await Draft(second,s.B);
  async Task<bool> Approve(SupplyOrderResponse o,Guid actor){try{await Call<ISupplyOrderService,SupplyOrderResponse>(f,x=>x.DecideAsync(o.HouseId,o.Id,actor,new(o.Version,true),default));return true;}catch(ConflictException){return false;}}
  var results=await Task.WhenAll(Approve(a,s.A),Approve(b,s.B));Assert.Single(results,x=>x);
  await using var read=f.Services.CreateAsyncScope();Assert.Equal(0,(await read.ServiceProvider.GetRequiredService<AppDbContext>().SupplyProducts.SingleAsync()).AvailableQuantity);
 }
 [PostgresFact]public async Task DeliveryProblemRequiresSupplierResponseAndClaimantAcceptance(){
  var gateway=new Gateway();await using var f=await PostgresFixture.CreateAsync(configure:s=>s.AddSingleton<IPurchasePaymentGateway>(gateway));var s=await Data(f);var order=await Buy(f,s,gateway);
  var claim=await Call<ISupplyDisputeService,SupplyDisputeResponse>(f,x=>x.CreateAsync(order.Id,s.B,new(Guid.NewGuid(),"One bag damaged",s.Product),default));
  await Assert.ThrowsAsync<ForbiddenException>(()=>Call<ISupplyDisputeService,SupplyDisputeResponse>(f,x=>x.ProposeAsync(order.Id,claim.Id,s.A,new("Replacement delivered"),default)));
  await Call<ISupplyDisputeService,SupplyDisputeResponse>(f,x=>x.ProposeAsync(order.Id,claim.Id,s.SupplierActor,new("Replacement delivered"),default));
  await Assert.ThrowsAsync<ForbiddenException>(()=>Call<ISupplyDisputeService,SupplyDisputeResponse>(f,x=>x.AcceptAsync(order.Id,claim.Id,s.A,default)));
  var accepted=await Call<ISupplyDisputeService,SupplyDisputeResponse>(f,x=>x.AcceptAsync(order.Id,claim.Id,s.B,default));Assert.NotNull(accepted.AcceptedAt);
  var summary=await Call<IInternalRepaymentService,PurchaseDebtSummaryResponse>(f,x=>x.SummaryAsync(s.House,s.A,default));Assert.Equal(240000,summary.OwedToMe);
 }
}
