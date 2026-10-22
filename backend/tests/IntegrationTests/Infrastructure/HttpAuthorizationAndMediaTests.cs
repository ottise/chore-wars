using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Entities;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Moq;
namespace IntegrationTests.Infrastructure;
public class HttpAuthorizationAndMediaTests {
    private static async Task<(Guid UserId,HttpClient Client,string RefreshToken)> Register(WebApplicationFactory<Program> factory) {
        var client=factory.CreateClient();var email=Guid.NewGuid()+"@example.test";
        var registration=await client.PostAsJsonAsync("/api/auth/register",new {Email=email,Password="ChoreTest!2026Ab",DisplayName="HTTP test member"});registration.EnsureSuccessStatusCode();
        var login=await client.PostAsJsonAsync("/api/auth/login",new {Email=email,Password="ChoreTest!2026Ab"});login.EnsureSuccessStatusCode();
        var payload=await login.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization=new AuthenticationHeaderValue("Bearer",payload.GetProperty("token").GetString());
        return(payload.GetProperty("userId").GetGuid(),client,payload.GetProperty("refreshToken").GetString()!);
    }
    [PostgresFact] public async Task EvidenceVisionAcceptsJsonObjectThroughAuthenticatedHttpWithoutCompletingChore() {
        var storage=new Mock<IMediaStorage>();var bytes=new Dictionary<string,byte[]>();
        storage.Setup(s=>s.WriteAsync(It.IsAny<string>(),It.IsAny<byte[]>(),It.IsAny<CancellationToken>())).Callback<string,byte[],CancellationToken>((key,value,_)=>bytes.Add(key,value)).Returns(Task.CompletedTask);
        storage.Setup(s=>s.ReadAsync(It.IsAny<string>(),It.IsAny<CancellationToken>())).Returns<string,CancellationToken>((key,_)=>Task.FromResult<Stream>(new MemoryStream(bytes[key])));
        var ai=new Mock<IAIHousekeeperClient>();
        ai.Setup(c=>c.PostAsync(It.IsAny<Guid>(),It.IsAny<Guid>(),"/v1/vision/verify-proof",It.IsAny<object>(),It.IsAny<CancellationToken>())).ReturnsAsync(JsonSerializer.SerializeToElement(new{result="UNCERTAIN",observations=Array.Empty<string>(),limitations=new[]{"Manual confirmation required"},can_complete_automatically=false}));
        await using var database=await PostgresFixture.CreateAsync();await using var parent=new ApiFactory(database);
        await using var factory=parent.WithWebHostBuilder(builder=>builder.ConfigureTestServices(services=>{services.AddSingleton(storage.Object);services.AddScoped(_=>ai.Object);}));
        var owner=await Register(factory);using var http=owner.Client;
        var created=await http.PostAsJsonAsync("/api/houses",new{Name="Evidence contract household"});created.EnsureSuccessStatusCode();
        var house=(await created.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();var occurrence=Guid.NewGuid();
        await using(var scope=database.Services.CreateAsyncScope()) {
            var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var season=new ChoreSeason{Id=Guid.NewGuid(),HouseId=house,Name="Evidence test",Status=SeasonStatus.ACTIVE,StartDate=DateTime.UtcNow.AddDays(-1),EndDate=DateTime.UtcNow.AddDays(2)};
            var chore=new Chore{Id=Guid.NewGuid(),HouseId=house,SeasonId=season.Id,Name="Dishes",Type=ChoreType.NORMAL,KarmaPoints=10};
            db.Seasons.Add(season);db.Chores.Add(chore);db.ChoreOccurrences.Add(new ChoreOccurrence{Id=occurrence,ChoreId=chore.Id,SeasonId=season.Id,AssignedUserId=owner.UserId,Status=ChoreOccurrenceStatus.ASSIGNED,DueDate=DateTime.UtcNow.AddDays(1),SnapshotMinutes=30,SnapshotKarma=10});
            db.HouseAiSettings.Add(new HouseAiSettings{HouseId=house,Enabled=true});await db.SaveChangesAsync();
        }
        using var form=new MultipartFormDataContent();form.Add(new StringContent(Guid.NewGuid().ToString()),"clientRequestId");form.Add(new ByteArrayContent(new byte[]{255,216,255,1,2,3,4,5,6,7,8,9}),"file","proof.jpg");
        var upload=await http.PostAsync($"/api/occurrences/{occurrence}/evidence",form);upload.EnsureSuccessStatusCode();
        var evidence=(await upload.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        var review=await http.PostAsJsonAsync($"/api/occurrences/{occurrence}/ai/verify-proof",new{evidenceId=evidence});review.EnsureSuccessStatusCode();
        Assert.False((await review.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("can_complete_automatically").GetBoolean());
        await using var read=database.Services.CreateAsyncScope();Assert.Equal(ChoreOccurrenceStatus.ASSIGNED,(await read.ServiceProvider.GetRequiredService<AppDbContext>().ChoreOccurrences.SingleAsync()).Status);
        ai.Verify(c=>c.PostAsync(house,owner.UserId,"/v1/vision/verify-proof",It.IsAny<object>(),It.IsAny<CancellationToken>()),Times.Once);
    }
    [PostgresFact] public async Task RealHttpPipelineProtectsHouseAndPrivateMedia() {
        await using var database=await PostgresFixture.CreateAsync();await using var factory=new ApiFactory(database);
        var owner=await Register(factory);using var ownerClient=owner.Client;
        var outsider=await Register(factory);using var outsiderClient=outsider.Client;
        var create=await ownerClient.PostAsJsonAsync("/api/houses",new{Name="HTTP test household"});create.EnsureSuccessStatusCode();
        var house=(await create.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.Forbidden,(await outsiderClient.GetAsync($"/api/houses/{house}/chores")).StatusCode);
        var roomResult=await ownerClient.GetAsync($"/api/houses/{house}/chat");roomResult.EnsureSuccessStatusCode();
        var room=(await roomResult.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        var png=Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWZkAAAAASUVORK5CYII=");
        using var upload=new MultipartFormDataContent();upload.Add(new StringContent(room.ToString()),"roomId");upload.Add(new ByteArrayContent(png),"file","proof.png");
        var uploaded=await ownerClient.PostAsync("/api/media",upload);uploaded.EnsureSuccessStatusCode();
        var media=(await uploaded.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.Forbidden,(await outsiderClient.GetAsync($"/api/media/{media}")).StatusCode);
        var clientId=Guid.NewGuid();
        var send=await ownerClient.PostAsJsonAsync("/api/media/send",new{RoomId=room,AttachmentId=media,ClientMessageId=clientId});send.EnsureSuccessStatusCode();
        var message=await send.Content.ReadFromJsonAsync<JsonElement>();Assert.Equal("IMAGE",message.GetProperty("messageType").GetString());
        var retry=await ownerClient.PostAsJsonAsync("/api/media/send",new{RoomId=room,AttachmentId=media,ClientMessageId=clientId});retry.EnsureSuccessStatusCode();
        Assert.Equal(message.GetProperty("id").GetGuid(),(await retry.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid());
        using var range=new HttpRequestMessage(HttpMethod.Get,$"/api/media/{media}");range.Headers.Range=new RangeHeaderValue(0,3);
        var partial=await ownerClient.SendAsync(range);Assert.Equal(HttpStatusCode.PartialContent,partial.StatusCode);Assert.Equal(png[..4],await partial.Content.ReadAsByteArrayAsync());
        var originalAuthorization=ownerClient.DefaultRequestHeaders.Authorization;
        var logout=await ownerClient.PostAsync("/api/auth/logout",null);logout.EnsureSuccessStatusCode();
        var deniedRefresh=await ownerClient.PostAsJsonAsync("/api/auth/refresh-token",new{RefreshToken=owner.RefreshToken});
        Assert.Equal(HttpStatusCode.Forbidden,deniedRefresh.StatusCode);
        ownerClient.DefaultRequestHeaders.Authorization=outsiderClient.DefaultRequestHeaders.Authorization;
        Assert.Equal(HttpStatusCode.Forbidden,(await ownerClient.GetAsync($"/api/media/{media}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,(await ownerClient.GetAsync($"/api/houses/{house}/chores")).StatusCode);
        ownerClient.DefaultRequestHeaders.Authorization=originalAuthorization;
        await using(var scope=database.Services.CreateAsyncScope()){var db=scope.ServiceProvider.GetRequiredService<AppDbContext>();var member=await db.HouseMembers.SingleAsync(x=>x.HouseId==house&&x.UserId==owner.UserId);member.Status=HouseMemberStatus.LEFT;await db.SaveChangesAsync();}
        Assert.Equal(HttpStatusCode.Forbidden,(await ownerClient.GetAsync($"/api/media/{media}")).StatusCode);
    }
}
