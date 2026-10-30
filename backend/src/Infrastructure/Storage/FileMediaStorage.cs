using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Options;
namespace ChoreWars.Infrastructure.Storage;
public class MediaStorageOptions { public string RootPath { get; set; } = Path.Combine(AppContext.BaseDirectory,"private-media"); }
public sealed class FileMediaStorage(IOptions<MediaStorageOptions> options) : IMediaStorage {
    private string FilePath(string key) {
        if (!Guid.TryParseExact(key,"N",out _)) throw new ArgumentException("Invalid storage key.");
        return Path.Combine(Path.GetFullPath(options.Value.RootPath),key);
    }
    public async Task WriteAsync(string key, byte[] data, CancellationToken ct) {
        var file = FilePath(key); Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        await using var stream = new FileStream(file,FileMode.CreateNew,FileAccess.Write,FileShare.None,81920,true);
        await stream.WriteAsync(data,ct);
    }
    public Task<Stream> ReadAsync(string key, CancellationToken ct) {
        try { return Task.FromResult<Stream>(new FileStream(FilePath(key),FileMode.Open,FileAccess.Read,FileShare.Read,81920,true)); }
        catch (FileNotFoundException) { throw new NotFoundException("Media file is unavailable."); }
        catch (DirectoryNotFoundException) { throw new NotFoundException("Media file is unavailable."); }
    }
    public Task DeleteAsync(string key, CancellationToken ct) {
        try { File.Delete(FilePath(key)); }
        catch (DirectoryNotFoundException) { /* Already absent, including after a server restart. */ }
        return Task.CompletedTask;
    }
}
