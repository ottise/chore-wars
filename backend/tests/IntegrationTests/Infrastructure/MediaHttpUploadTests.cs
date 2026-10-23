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
    }
}
