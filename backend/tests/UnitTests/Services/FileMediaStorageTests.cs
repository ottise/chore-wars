using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Storage;
using Microsoft.Extensions.Options;

namespace UnitTests.Services;

public class FileMediaStorageTests
{
    [Fact]
    public async Task LegacyRootIsReadableWithoutMovingOrOverwritingOriginalFile()
    {
        var root=Path.Combine(Path.GetTempPath(),"cw-legacy-root-"+Guid.NewGuid().ToString("N"));
        var key=Guid.NewGuid().ToString("N");
        var original=new FileMediaStorage(Options.Create(new MediaStorageOptions{RootPath=root}));
        try {
            await original.WriteAsync(key,[1,2,3,4],default);
            var storage=new FileMediaStorage(Options.Create(new MediaStorageOptions {
                RootPath=Path.Combine(root,"new"), LegacyRootPaths=[root]
            }));
            await using var stream=await storage.ReadAsync(key,default);
            using var buffer=new MemoryStream();await stream.CopyToAsync(buffer);
            Assert.Equal(new byte[]{1,2,3,4},buffer.ToArray());
            Assert.True(File.Exists(Path.Combine(root,key)));
            Assert.False(Directory.Exists(Path.Combine(root,"new")));
            await Assert.ThrowsAsync<ArgumentException>(()=>storage.ReadAsync("../bad",default));
        } finally {
            await original.DeleteAsync(key,default);
            if(Directory.Exists(root))Directory.Delete(root);
        }
    }

    [Fact]
    public async Task SeparateBuildsReadTheSameConfiguredMediaRoot()
    {
        var root=Path.Combine(Path.GetTempPath(),"cw-media-"+Guid.NewGuid().ToString("N"));
        var key=Guid.NewGuid().ToString("N");
        var options=Options.Create(new MediaStorageOptions{RootPath=root});
        var writer=new FileMediaStorage(options);
        try {
            await writer.WriteAsync(key,[82,73,70,70],default);
            var reader=new FileMediaStorage(options);
            await using var stream=await reader.ReadAsync(key,default);
            using var buffer=new MemoryStream();
            await stream.CopyToAsync(buffer);
            Assert.Equal(new byte[]{82,73,70,70},buffer.ToArray());
        }
        finally {
            await writer.DeleteAsync(key,default);
            if (Directory.Exists(root)) Directory.Delete(root);
        }
    }

    [Fact]
    public async Task MissingMediaIsReportedAsNotFoundWithoutDisclosingDiskPaths()
    {
        var root=Path.Combine(Path.GetTempPath(),"cw-media-"+Guid.NewGuid().ToString("N"));
        var storage=new FileMediaStorage(Options.Create(new MediaStorageOptions{RootPath=root}));
        var error=await Assert.ThrowsAsync<NotFoundException>(()=>storage.ReadAsync(Guid.NewGuid().ToString("N"),default));
        Assert.DoesNotContain(root,error.Message);
        Assert.Contains("unavailable",error.Message);
    }
}
