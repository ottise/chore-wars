using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.Caching.Memory;
using SkiaSharp;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Infrastructure.Storage;
public sealed class EvidenceThumbnailService(IEvidenceService evidence, IMemoryCache cache) : IEvidenceThumbnailService
{
    private const int Edge = 96;
    private static readonly TimeSpan CacheLifetime = TimeSpan.FromMinutes(2);
    private static readonly SemaphoreSlim DecodeSlots = new(2);
    public async Task<byte[]> ReadAsync(Guid evidenceId, Guid actor, CancellationToken ct)
    {
        var authorized = await evidence.ReadAsync(evidenceId, actor, ct);
        await using var input = authorized.Stream;
        var key = (typeof(EvidenceThumbnailService), evidenceId);
        if (cache.TryGetValue<byte[]>(key, out var existing)) return existing!;
        await DecodeSlots.WaitAsync(ct);
        try
        {
            using var codec = SKCodec.Create(input);
            if (codec == null || (long)codec.Info.Width * codec.Info.Height > 16777216) throw new DomainException("Evidence preview is unavailable.");
            var ratio = Math.Min(1f, (float)Edge / Math.Max(codec.Info.Width, codec.Info.Height));
            var size = codec.GetScaledDimensions(ratio);
            using var bitmap = new SKBitmap(size.Width, size.Height);
            if (codec.GetPixels(bitmap.Info, bitmap.GetPixels()) != SKCodecResult.Success) throw new DomainException("Evidence preview is unavailable.");
            var target = new SKImageInfo(Math.Max(1, (int)(codec.Info.Width * ratio)), Math.Max(1, (int)(codec.Info.Height * ratio)));
            using var small = bitmap.Resize(target, new SKSamplingOptions(SKFilterMode.Linear));
            var rotate = codec.EncodedOrigin is SKEncodedOrigin.LeftTop or SKEncodedOrigin.RightTop or SKEncodedOrigin.RightBottom or SKEncodedOrigin.LeftBottom;
            using var oriented = new SKBitmap(rotate ? small.Height : small.Width, rotate ? small.Width : small.Height);
            using (var canvas = new SKCanvas(oriented))
            {
                switch (codec.EncodedOrigin)
                {
                    case SKEncodedOrigin.TopRight: canvas.Translate(oriented.Width, 0); canvas.Scale(-1, 1); break;
                    case SKEncodedOrigin.BottomRight: canvas.Translate(oriented.Width, oriented.Height); canvas.RotateDegrees(180); break;
                    case SKEncodedOrigin.BottomLeft: canvas.Translate(0, oriented.Height); canvas.Scale(1, -1); break;
                    case SKEncodedOrigin.LeftTop: canvas.RotateDegrees(90); canvas.Scale(1, -1); break;
                    case SKEncodedOrigin.RightTop: canvas.Translate(oriented.Width, 0); canvas.RotateDegrees(90); break;
                    case SKEncodedOrigin.RightBottom: canvas.Translate(oriented.Width, oriented.Height); canvas.RotateDegrees(90); canvas.Scale(-1, 1); break;
                    case SKEncodedOrigin.LeftBottom: canvas.Translate(0, oriented.Height); canvas.RotateDegrees(270); break;
                }
                canvas.DrawBitmap(small, 0, 0);
            }
            using var image = SKImage.FromBitmap(oriented);
            using var encoded = image.Encode(SKEncodedImageFormat.Jpeg, 65);
            var bytes = encoded.ToArray(); cache.Set(key, bytes, CacheLifetime); return bytes;
        }
        finally { DecodeSlots.Release(); }
    }
}
