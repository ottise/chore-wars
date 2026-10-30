using System.Net;
using System.Net.Http.Headers;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Storage;
using Microsoft.Extensions.Hosting;
using Moq;

namespace UnitTests.Services;
public class GoogleAvatarProxyTests
{
    private sealed class Handler(int status, string type, long length) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Assert.Null(request.Headers.Authorization);
            var content = new ByteArrayContent([1]);
            content.Headers.ContentType = new MediaTypeHeaderValue(type); content.Headers.ContentLength = length;
            return Task.FromResult(new HttpResponseMessage((HttpStatusCode)status) { Content = content });
        }
    }
    [Theory]
    [InlineData(302, "image/png", 1)]
    [InlineData(200, "text/html", 1)]
    [InlineData(200, "image/png", 5242881)]
    public async Task RemoteAvatarRejectsRedirectsNonImagesAndOversizedBodies(int status, string type, long length)
    {
        var clients = new Mock<IHttpClientFactory>();
        clients.Setup(x => x.CreateClient("google-avatar")).Returns(() => new HttpClient(new Handler(status, type, length)));
        var avatars = new AvatarStorage(Mock.Of<IHostEnvironment>(), null!, clients.Object);
        await Assert.ThrowsAsync<NotFoundException>(() => avatars.ReadAsync("https://lh3.googleusercontent.com/a/test", default));
    }
}
