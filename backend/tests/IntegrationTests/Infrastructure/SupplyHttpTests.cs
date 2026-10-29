using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Domain.Entities;
using ChoreWars.Infrastructure.Data;
using Microsoft.Extensions.DependencyInjection;
namespace IntegrationTests.Infrastructure;
public sealed class SupplyHttpTests
{
 [PostgresFact] public async Task PersonalFinanceEndpointsUseTheTokenActorAndRejectDebtFromAnotherHeaderHouse(){
  await using var f=await PostgresFixture.CreateAsync();await using var factory=new ApiFactory(f);using var a=factory.CreateClient();using var b=factory.CreateClient();
  var actor=await Login(a,"Finance A");var other=await Login(b,"Finance B");
  async Task<Guid> House(string name){var r=await a.PostAsJsonAsync("/api/houses",new{name});r.EnsureSuccessStatusCode();return(await r.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();}
  var houseA=await House("Finance house A");var houseB=await House("Finance house B");var debt=Guid.NewGuid();
  await using(var scope=factory.Services.CreateAsyncScope()){var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();db.PaymentObligations.Add(new(){Id=debt,HouseId=houseB,DebtorUserId=other,CreditorUserId=actor,Amount=1000,CreatedAt=DateTime.UtcNow});await db.SaveChangesAsync();}
  var date=DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7)).ToString("yyyy-MM-dd");
  Assert.Equal(HttpStatusCode.Forbidden,(await b.GetAsync($"/api/houses/{houseA}/me/payment-history?from={date}&to={date}")).StatusCode);
  Assert.Equal(HttpStatusCode.NotFound,(await a.GetAsync($"/api/houses/{houseA}/me/debts/{debt}")).StatusCode);
  Assert.Equal(HttpStatusCode.OK,(await a.GetAsync($"/api/houses/{houseB}/me/debts/{debt}")).StatusCode);
  var empty=await a.GetFromJsonAsync<JsonElement>($"/api/houses/{houseA}/me/debts");Assert.Empty(empty.GetProperty("debts").EnumerateArray());
  Assert.Equal(HttpStatusCode.BadRequest,(await a.GetAsync($"/api/houses/{houseA}/me/payment-history?from={date}&to={date}&page=0")).StatusCode);
  Assert.Equal(HttpStatusCode.OK,(await a.GetAsync($"/api/houses/{houseA}/summary?from={date}&to={date}")).StatusCode);
 }
 private static async Task<Guid> Login(HttpClient c,string name){var email=$"{name}-{Guid.NewGuid():N}@test.example";var credentials=new{email,password="TestPassword1!",displayName=name};(await c.PostAsJsonAsync("/api/auth/register",credentials)).EnsureSuccessStatusCode();var response=await c.PostAsJsonAsync("/api/auth/login",credentials);response.EnsureSuccessStatusCode();var token=(await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("token").GetString();c.DefaultRequestHeaders.Authorization=new AuthenticationHeaderValue("Bearer",token);return(await c.GetFromJsonAsync<JsonElement>("/api/user/profile")).GetProperty("id").GetGuid();}
 [PostgresFact]public async Task RealHttpChecksHouseScopeValidationAndKeepsBankDetailsPrivate(){
  await using var db=await PostgresFixture.CreateAsync();await using var factory=new ApiFactory(db);using var a=factory.CreateClient();using var b=factory.CreateClient();using var anonymous=factory.CreateClient();
  var actor=await Login(a,"A");await Login(b,"B");
  var houseResponse=await a.PostAsJsonAsync("/api/houses",new{name="Supply HTTP test"});houseResponse.EnsureSuccessStatusCode();var house=(await houseResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
  var supplier=Guid.NewGuid();await using(var scope=factory.Services.CreateAsyncScope()){var context=scope.ServiceProvider.GetRequiredService<AppDbContext>();context.Suppliers.Add(new Supplier{Id=supplier,OperatorUserId=actor,Name="HTTP test supplier",Email="shop@test.example",DeliveryArea="Test area"});await context.SaveChangesAsync();}
  Assert.Equal(HttpStatusCode.Unauthorized,(await anonymous.GetAsync("/api/suppliers")).StatusCode);
  var catalog=await a.GetFromJsonAsync<JsonElement>("/api/suppliers");Assert.Equal("shop@test.example",catalog[0].GetProperty("email").GetString());Assert.False(catalog[0].TryGetProperty("operatorUserId",out _));
  Assert.Equal(HttpStatusCode.Forbidden,(await b.GetAsync($"/api/houses/{house}/supply-orders")).StatusCode);
  Assert.Equal(HttpStatusCode.BadRequest,(await a.PostAsJsonAsync($"/api/houses/{house}/supply-orders",new{clientRequestId=Guid.NewGuid(),supplierId=supplier,payerUserId=actor,deliveryAddress="Test address",contactPhone="0123456789",lines=Array.Empty<object>(),shares=new[]{new{userId=actor}}})).StatusCode);
  var saved=await a.PutAsJsonAsync("/api/user/bank-account",new{bankName="Test bank",accountNumber="123456789",accountName="A"});saved.EnsureSuccessStatusCode();
  var own=await a.GetFromJsonAsync<JsonElement>("/api/user/bank-account");Assert.Equal("123456789",own.GetProperty("accountNumber").GetString());
  var others=await b.GetAsync("/api/user/bank-account");Assert.True(others.IsSuccessStatusCode);Assert.DoesNotContain("123456789",await others.Content.ReadAsStringAsync());
  Assert.Equal(HttpStatusCode.BadRequest,(await b.PutAsJsonAsync("/api/user/bank-account",new{bankName="Bank",accountNumber="not a number",accountName="B"})).StatusCode);
 }
}
