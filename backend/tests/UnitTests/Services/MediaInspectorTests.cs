using System.Buffers.Binary;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Exceptions;
namespace UnitTests.Services;
public class MediaInspectorTests {
    [Fact] public void RejectsExtensionSpoofedAudio() => Assert.Throws<DomainException>(()=>MediaInspector.Inspect("not audio"u8.ToArray()));
    [Fact] public void EnforcesSizeLimit() => Assert.Throws<DomainException>(()=>MediaInspector.Inspect(new byte[5*1024*1024+1]));
    [Theory] [InlineData(60,true)] [InlineData(61,false)]
    public void ReadsDurationFromMp4Header(int seconds,bool allowed) {
        var bytes=new byte[64];
        BinaryPrimitives.WriteUInt32BigEndian(bytes.AsSpan(0,4),16);"ftyp"u8.CopyTo(bytes.AsSpan(4));
        BinaryPrimitives.WriteUInt32BigEndian(bytes.AsSpan(16,4),48);"moov"u8.CopyTo(bytes.AsSpan(20));
        BinaryPrimitives.WriteUInt32BigEndian(bytes.AsSpan(24,4),32);"mvhd"u8.CopyTo(bytes.AsSpan(28));
        BinaryPrimitives.WriteUInt32BigEndian(bytes.AsSpan(44,4),1000);BinaryPrimitives.WriteUInt32BigEndian(bytes.AsSpan(48,4),(uint)seconds*1000);
        "mp4a"u8.CopyTo(bytes.AsSpan(56));
        if(allowed)Assert.Equal(seconds,MediaInspector.Inspect(bytes).Duration);else Assert.Throws<DomainException>(()=>MediaInspector.Inspect(bytes));
    }
}
