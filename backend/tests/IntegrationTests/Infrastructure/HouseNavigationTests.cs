using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Application.DTOs.House;

namespace IntegrationTests.Infrastructure;

public sealed class HouseNavigationTests
{
    [PostgresFact]
    public async Task QrInvitationPreviewRequiresLoginAndJoiningRevalidatesRotatedCode()
    {
        await using var database = await PostgresFixture.CreateAsync();
        await using var factory = new ApiFactory(database);
        using var owner = factory.CreateClient();
        using var member = factory.CreateClient();
        using var anonymous = factory.CreateClient();
        await RegisterAndLogin(owner, "qr-owner");
        await RegisterAndLogin(member, "qr-member");
        var created = await owner.PostAsJsonAsync("/api/houses", new { Name = "QR invitation test" });
        created.EnsureSuccessStatusCode();
        var house = (await created.Content.ReadFromJsonAsync<HouseResponse>())!;
        var previewPath = $"/api/invitations/{house.InviteCode}/preview";

        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync(previewPath)).StatusCode);
        var preview = await member.GetFromJsonAsync<JsonElement>(previewPath);
        Assert.Equal(house.Name, preview.GetProperty("name").GetString());
        Assert.Equal(1, preview.GetProperty("activeMembers").GetInt32());
        Assert.Equal(6, preview.GetProperty("capacity").GetInt32());
        Assert.Empty((await member.GetFromJsonAsync<List<HouseResponse>>("/api/houses/my-houses"))!);
        Assert.Equal(HttpStatusCode.Forbidden, (await member.PostAsync($"/api/houses/{house.Id}/rotate-invite", null)).StatusCode);

        var rotation = await owner.PostAsync($"/api/houses/{house.Id}/rotate-invite", null);
        rotation.EnsureSuccessStatusCode();
        var code = (await rotation.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("inviteCode").GetString()!;
        Assert.NotEqual(house.InviteCode, code);
        Assert.Equal(HttpStatusCode.NotFound, (await member.GetAsync(previewPath)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await member.PostAsJsonAsync("/api/houses/join", new { house.InviteCode })).StatusCode);
        (await member.GetAsync($"/api/invitations/{code}/preview")).EnsureSuccessStatusCode();
        (await member.PostAsJsonAsync("/api/houses/join", new { InviteCode = code })).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Conflict, (await member.PostAsJsonAsync("/api/houses/join", new { InviteCode = code })).StatusCode);
        var joined = Assert.Single((await member.GetFromJsonAsync<List<HouseResponse>>("/api/houses/my-houses"))!);
        Assert.Equal(house.Id, joined.Id);
        Assert.Equal("MEMBER", joined.CurrentUserRole);
        Assert.Equal(2, (await member.GetFromJsonAsync<JsonElement>($"/api/invitations/{code}/preview")).GetProperty("activeMembers").GetInt32());
    }

    [PostgresFact]
    public async Task MyHousesReturnsRolesAndExcludesLeftMembershipsThroughRealLogin()
    {
        await using var database = await PostgresFixture.CreateAsync();
        await using var factory = new ApiFactory(database);
        using var owner = factory.CreateClient();
        using var member = factory.CreateClient();
        using var outsider = factory.CreateClient();
        await RegisterAndLogin(owner, "owner");
        await RegisterAndLogin(member, "member");
        await RegisterAndLogin(outsider, "outsider");

        var created = await owner.PostAsJsonAsync("/api/houses", new { Name = "Navigation test" });
        created.EnsureSuccessStatusCode();
        var house = (await created.Content.ReadFromJsonAsync<HouseResponse>())!;
        (await member.PostAsJsonAsync("/api/houses/join", new { house.InviteCode })).EnsureSuccessStatusCode();

        var ownerHouses = await owner.GetFromJsonAsync<List<HouseResponse>>("/api/houses/my-houses");
        Assert.Equal(house.Id, Assert.Single(ownerHouses!).Id);
        Assert.Equal("OWNER", ownerHouses![0].CurrentUserRole);
        var memberHouses = await member.GetFromJsonAsync<List<HouseResponse>>("/api/houses/my-houses");
        Assert.Equal("MEMBER", Assert.Single(memberHouses!).CurrentUserRole);
        Assert.Empty((await outsider.GetFromJsonAsync<List<HouseResponse>>("/api/houses/my-houses"))!);

        (await member.DeleteAsync($"/api/houses/{house.Id}/leave")).EnsureSuccessStatusCode();
        Assert.Empty((await member.GetFromJsonAsync<List<HouseResponse>>("/api/houses/my-houses"))!);
        Assert.Equal(HttpStatusCode.Forbidden, (await member.GetAsync($"/api/houses/{house.Id}")).StatusCode);
    }

    private static async Task RegisterAndLogin(HttpClient client, string name)
    {
        var email = $"{name}-{Guid.NewGuid():N}@example.test";
        const string password = "Navigation-test-2026!";
        (await client.PostAsJsonAsync("/api/auth/register", new { Email = email, Password = password, DisplayName = name })).EnsureSuccessStatusCode();
        var login = await client.PostAsJsonAsync("/api/auth/login", new { Email = email, Password = password });
        login.EnsureSuccessStatusCode();
        var json = await login.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", json.GetProperty("token").GetString());
    }
}
