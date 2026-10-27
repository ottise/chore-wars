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
