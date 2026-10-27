using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.DTOs.Chat;

namespace IntegrationTests.Infrastructure;

public sealed class MediaHttpUploadTests
{
    [PostgresFact]
    public async Task CameraPhotoUploadsAndSendsThroughAuthenticatedHttpEndpoints()
    {
        await using var database = await PostgresFixture.CreateAsync();
        await using var factory = new ApiFactory(database);
        using var client = factory.CreateClient();
        var email = $"camera-{Guid.NewGuid():N}@example.test";
        const string password = "Camera-test-2026!";
        (await client.PostAsJsonAsync("/api/auth/register", new { Email = email, Password = password, DisplayName = "Camera Test" })).EnsureSuccessStatusCode();
        var login = await client.PostAsJsonAsync("/api/auth/login", new { Email = email, Password = password });
        login.EnsureSuccessStatusCode();
        var auth = await login.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("token").GetString());
        var created = await client.PostAsJsonAsync("/api/houses", new { Name = "Camera Upload Test" });
        created.EnsureSuccessStatusCode();
        var house = (await created.Content.ReadFromJsonAsync<HouseResponse>())!;
        var room = (await client.GetFromJsonAsync<ChatRoomResponse>($"/api/houses/{house.Id}/chat"))!;
        using var form = new MultipartFormDataContent();
        form.Add(new StringContent(room.Id.ToString()), "roomId");
        form.Add(new ByteArrayContent([255, 216, 255, 1]), "file", "attachment");
        var uploaded = await client.PostAsync("/api/media", form);
        var response = await uploaded.Content.ReadAsStringAsync();
        Assert.True(uploaded.IsSuccessStatusCode, $"Upload status {(int)uploaded.StatusCode}: {response}");
        var attachmentId = JsonDocument.Parse(response).RootElement.GetProperty("id").GetGuid();
        var sent = await client.PostAsJsonAsync("/api/media/send", new { RoomId = room.Id, AttachmentId = attachmentId, ClientMessageId = Guid.NewGuid() });
        var result = await sent.Content.ReadAsStringAsync();
        Assert.True(sent.IsSuccessStatusCode, $"Send status {(int)sent.StatusCode}: {result}");
        Assert.Equal("IMAGE", JsonDocument.Parse(result).RootElement.GetProperty("messageType").GetString());
        var photos = await client.GetFromJsonAsync<PagedResult<ChatMessageResponse>>($"/api/chat/rooms/{room.Id}/photos?page=1&pageSize=1");
        Assert.Equal(1, photos!.TotalCount);
        Assert.Equal(attachmentId, Assert.Single(photos.Items).AttachmentId);
        Assert.Empty((await client.GetFromJsonAsync<PagedResult<ChatMessageResponse>>($"/api/chat/rooms/{room.Id}/photos?page=2&pageSize=1"))!.Items);
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, (await client.GetAsync($"/api/chat/rooms/{room.Id}/photos?pageSize=101")).StatusCode);
        using var anonymous = factory.CreateClient();
        Assert.Equal(System.Net.HttpStatusCode.Unauthorized, (await anonymous.GetAsync($"/api/chat/rooms/{room.Id}/photos")).StatusCode);
    }

    [PostgresFact]
    public async Task AvatarUploadSurvivesProfileReloadAndImageRequiresItsOwnersLogin()
    {
        await using var database = await PostgresFixture.CreateAsync();
        await using var factory = new ApiFactory(database);
        using var client = factory.CreateClient();
        var email = $"avatar-{Guid.NewGuid():N}@example.test";
        const string password = "Avatar-test-2026!";
        (await client.PostAsJsonAsync("/api/auth/register", new { Email = email, Password = password, DisplayName = "Avatar Test" })).EnsureSuccessStatusCode();
        var login = await client.PostAsJsonAsync("/api/auth/login", new { Email = email, Password = password });
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", (await login.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("token").GetString());
        var png = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWZkAAAAASUVORK5CYII=");
        using var form = new MultipartFormDataContent();
        form.Add(new ByteArrayContent(png), "file", "avatar.png");
        var uploaded = await client.PostAsync("/api/user/avatar", form);
        uploaded.EnsureSuccessStatusCode();
        var avatar = (await uploaded.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("avatarUrl").GetString();
        Assert.StartsWith("/avatars/", avatar);
        (await client.PutAsJsonAsync("/api/user/profile", new { DisplayName = "Renamed" })).EnsureSuccessStatusCode();
        var profile = await client.GetFromJsonAsync<JsonElement>("/api/user/profile");
        Assert.Equal(avatar, profile.GetProperty("avatarUrl").GetString());
        Assert.Equal("Renamed", profile.GetProperty("displayName").GetString());
        var image = await client.GetAsync("/api/user/avatar-image");
        image.EnsureSuccessStatusCode();
        Assert.Equal(png, await image.Content.ReadAsByteArrayAsync());
        Assert.Equal("image/png", image.Content.Headers.ContentType!.MediaType);
        using var anonymous = factory.CreateClient();
        Assert.Equal(System.Net.HttpStatusCode.Unauthorized, (await anonymous.GetAsync("/api/user/avatar-image")).StatusCode);
    }
}
