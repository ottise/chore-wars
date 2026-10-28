using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Storage;
using Microsoft.Extensions.Caching.Memory;
using Moq;
using SkiaSharp;
namespace UnitTests.Services;
public class EvidenceThumbnailTests
{
    [Fact]
    public async Task ThumbnailIsSmallAndCachedButEveryReadStillChecksAuthorization()
    {
        var id = Guid.NewGuid(); var member = Guid.NewGuid(); var outsider = Guid.NewGuid();
        using var source = new SKBitmap(400, 200); using var image = SKImage.FromBitmap(source); using var encoded = image.Encode(SKEncodedImageFormat.Png, 100);
        var evidence = new Mock<IEvidenceService>();
        evidence.Setup(x => x.ReadAsync(id, member, It.IsAny<CancellationToken>())).ReturnsAsync(() => new AIEvidenceContent(new MemoryStream(encoded.ToArray()), "image/png"));
        evidence.Setup(x => x.ReadAsync(id, outsider, It.IsAny<CancellationToken>())).ThrowsAsync(new ForbiddenException());
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var thumbnails = new EvidenceThumbnailService(evidence.Object, cache);
        var first = await thumbnails.ReadAsync(id, member, default);
        using var decoded = SKBitmap.Decode(first); Assert.Equal(96, decoded.Width); Assert.Equal(48, decoded.Height);
        Assert.Same(first, await thumbnails.ReadAsync(id, member, default));
        await Assert.ThrowsAsync<ForbiddenException>(() => thumbnails.ReadAsync(id, outsider, default));
        evidence.Verify(x => x.ReadAsync(id, member, It.IsAny<CancellationToken>()), Times.Exactly(2));
    }
}
