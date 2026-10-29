using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Infrastructure.Data;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Moq;

namespace IntegrationTests.Infrastructure;

public class ShopOrderJourneyTests
{
    [PostgresFact]
    public async Task HttpCreateContactPrepareSmsRecordPaymentAndReloadHistoryAreConnected()
    {
        await using var db = await PostgresFixture.CreateAsync();
        using var root = new ApiFactory(db);
        var sender = new Mock<ISupplyOrderEmailSender>();
        sender.SetupGet(s => s.IsConfigured).Returns(true);
        using var factory = root.WithWebHostBuilder(b => b.ConfigureTestServices(services => {
            services.RemoveAll<ISupplyOrderEmailSender>(); services.AddSingleton(sender.Object);
        }));
        using var client = factory.CreateClient();
        using var outsider = factory.CreateClient();
        async Task<Guid> Login(HttpClient c, string name)
        {
            var credentials = new { email = $"{Guid.NewGuid():N}@example.test", displayName = name, password = "TestPassword1!" };
            (await c.PostAsJsonAsync("/api/auth/register", credentials)).EnsureSuccessStatusCode();
            var login = await c.PostAsJsonAsync("/api/auth/login", credentials); login.EnsureSuccessStatusCode();
            var value = await login.Content.ReadFromJsonAsync<JsonElement>();
            c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", value.GetProperty("token").GetString());
            return value.GetProperty("userId").GetGuid();
        }
        var actor = await Login(client, "Shop owner"); await Login(outsider, "Other household");
        var houseResponse = await client.PostAsJsonAsync("/api/houses", new { name = "Shop journey" }); houseResponse.EnsureSuccessStatusCode();
        var house = (await houseResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        var request = new { clientRequestId = Guid.NewGuid(), name = "ST25 rice", unit = "5 kg bag", price = 150000,
            contactName = "Rice shop", phone = "0901234567", email = "rice@example.test" };
        Assert.Equal(HttpStatusCode.Forbidden, (await outsider.PostAsJsonAsync($"/api/houses/{house}/shop/items", request)).StatusCode);
        var create = await client.PostAsJsonAsync($"/api/houses/{house}/shop/items", request); create.EnsureSuccessStatusCode();
        var item = await create.Content.ReadFromJsonAsync<JsonElement>();
        var supplier = item.GetProperty("supplier").GetProperty("id").GetGuid();
        var product = item.GetProperty("product").GetProperty("id").GetGuid();
        (await client.PostAsJsonAsync($"/api/houses/{house}/shop/items", request)).EnsureSuccessStatusCode();
        Assert.Equal(1, (await client.GetFromJsonAsync<JsonElement>($"/api/houses/{house}/shop/suppliers")).GetArrayLength());
        Assert.Equal("ST25 rice", (await client.GetFromJsonAsync<JsonElement>($"/api/suppliers/{supplier}/products"))[0].GetProperty("name").GetString());
        var sendRequest = new { clientRequestId = Guid.NewGuid(), supplierId = supplier, lines = new[] { new { productId = product, quantity = 2 } } };
        var send = await client.PostAsJsonAsync($"/api/houses/{house}/orders/send", sendRequest); send.EnsureSuccessStatusCode();
        var order = await send.Content.ReadFromJsonAsync<JsonElement>(); var id = order.GetProperty("id").GetGuid();
        Assert.Equal(300000, order.GetProperty("total").GetDecimal());
        Assert.Equal("SIMPLE_SMS", order.GetProperty("workflow").GetString());
        Assert.Equal("0901234567", order.GetProperty("supplierPhone").GetString());
        (await client.PostAsJsonAsync($"/api/houses/{house}/orders/send", sendRequest)).EnsureSuccessStatusCode();
        var payment = new { clientRequestId = Guid.NewGuid(), amount = 300000, reference = "test bank transfer" };
        (await client.PostAsJsonAsync($"/api/houses/{house}/orders/{id}/record-payment", payment)).EnsureSuccessStatusCode();
        (await client.PostAsJsonAsync($"/api/houses/{house}/orders/{id}/record-payment", payment)).EnsureSuccessStatusCode();
        var history = await client.GetFromJsonAsync<JsonElement>($"/api/houses/{house}/supply-orders");
        Assert.Equal(1, history.GetArrayLength());
        var detail = await client.GetFromJsonAsync<JsonElement>($"/api/houses/{house}/supply-orders/{id}");
        Assert.Equal("PAID", detail.GetProperty("status").GetString());
        Assert.Equal(actor, detail.GetProperty("paymentRecordedByUserId").GetGuid());
        Assert.Equal(300000, detail.GetProperty("recordedPaidAmount").GetDecimal());
        Assert.Equal("NOT_REQUESTED", detail.GetProperty("emailStatus").GetString());
        Assert.Equal(HttpStatusCode.Forbidden, (await outsider.GetAsync($"/api/houses/{house}/supply-orders/{id}")).StatusCode);
        await using var read = factory.Services.CreateAsyncScope();
        var context = read.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await context.Suppliers.CountAsync()); Assert.Equal(1, await context.SupplyProducts.CountAsync());
        Assert.Equal(1, await context.SupplyOrders.CountAsync()); Assert.Equal(0, await context.SupplyOrderEmailDispatches.CountAsync());
        Assert.Equal(1, await context.SupplyOrderActivities.CountAsync(a => a.Kind == OrderEmailState.UserReported));
    }
}
