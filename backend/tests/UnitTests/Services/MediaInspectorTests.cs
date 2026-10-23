using System.Buffers.Binary;
using ChoreWars.Application.Services;
using ChoreWars.Domain.Exceptions;
namespace UnitTests.Services;
public class MediaInspectorTests {
    private static byte[] Wav(int seconds) {
        var bytes = new byte[44 + 16000 * 2 * seconds];
        "RIFF"u8.CopyTo(bytes); BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(4), (uint)bytes.Length - 8);
        "WAVEfmt "u8.CopyTo(bytes.AsSpan(8)); BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(16), 16);
        BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(20), 1); BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(22), 1);
        BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(24), 16000); BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(28), 32000);
        BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(32), 2); BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(34), 16);
        "data"u8.CopyTo(bytes.AsSpan(36)); BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(40), (uint)bytes.Length - 44);
        return bytes;
    }
    [Theory] [InlineData(1)] [InlineData(60)]
    public void AcceptsBrowserPcmWavWithActualDuration(int seconds) {
        var result = MediaInspector.Inspect(Wav(seconds));
        Assert.Equal("audio/wav", result.Mime); Assert.Equal(seconds, result.Duration);
    }
    [Fact] public void RejectsWavOverSixtySeconds() => Assert.Throws<DomainException>(() => MediaInspector.Inspect(Wav(61)));
    [Fact] public void RejectsTruncatedWav() => Assert.Throws<DomainException>(() => MediaInspector.Inspect(Wav(2)[..^10]));
    [Fact] public void RejectsForgedWavByteRate() {
        var bytes = Wav(1); BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(28), 1);
        Assert.Throws<DomainException>(() => MediaInspector.Inspect(bytes));
    }
    [Fact] public void RejectsTrailingWavGarbageInsideRiff() {
        var bytes = Wav(1).Concat(new byte[] { 1 }).ToArray();
        BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(4), (uint)bytes.Length - 8);
        Assert.Throws<DomainException>(() => MediaInspector.Inspect(bytes));
    }
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
