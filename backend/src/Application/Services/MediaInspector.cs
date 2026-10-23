using System.Buffers.Binary;
using System.Text;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public static class MediaInspector {
    public static (string Mime, string Type, int? Duration) Inspect(byte[] data) {
        if (data.Length == 0 || data.Length > 5 * 1024 * 1024) throw new DomainException("Media must be between 1 byte and 5 MB.");
        if (data.Length >= 8 && data.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10})) return ("image/png", "IMAGE", null);
        if (data.Length >= 3 && data[0] == 255 && data[1] == 216 && data[2] == 255) return ("image/jpeg", "IMAGE", null);
        if (data.Length >= 12 && data.AsSpan(0,4).SequenceEqual("RIFF"u8) && data.AsSpan(8,4).SequenceEqual("WAVE"u8)) {
            var duration = WavDuration(data);
            if (duration is > 0 and <= 60) return ("audio/wav", "AUDIO", (int)Math.Ceiling(duration.Value));
            throw new DomainException("Voice notes must be valid PCM WAV and at most 60 seconds.");
        }
        if (data.Length >= 16 && Encoding.ASCII.GetString(data,4,4) == "ftyp") {
            var seconds = Duration(data, 0, data.Length);
            if (seconds is > 0 and <= 60 && data.AsSpan().IndexOf("mp4a"u8) >= 0) return ("audio/mp4", "AUDIO", (int)Math.Ceiling(seconds.Value));
            throw new DomainException("Voice notes must be AAC in M4A and at most 60 seconds.");
        }
        throw new DomainException("Supported media: JPEG, PNG, AAC M4A, or PCM WAV.");
    }
    private static double? WavDuration(byte[] data) {
        if (BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(4,4)) != data.Length - 8) return null;
        uint? byteRate = null, payloadSize = null;
        ushort? frameSize = null;
        var pos = 12;
        for (; pos <= data.Length - 8;) {
            var size = BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(pos + 4,4));
            if (size > data.Length - pos - 8) return null;
            var body = pos + 8;
            if (data.AsSpan(pos,4).SequenceEqual("fmt "u8)) {
                if (byteRate.HasValue || size < 16) return null;
                var format = BinaryPrimitives.ReadUInt16LittleEndian(data.AsSpan(body,2));
                var channels = BinaryPrimitives.ReadUInt16LittleEndian(data.AsSpan(body + 2,2));
                var rate = BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(body + 4,4));
                var bytesPerSecond = BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(body + 8,4));
                var alignment = BinaryPrimitives.ReadUInt16LittleEndian(data.AsSpan(body + 12,2));
                var bits = BinaryPrimitives.ReadUInt16LittleEndian(data.AsSpan(body + 14,2));
                if (format != 1 || channels is < 1 or > 2 || rate is < 8000 or > 48000 || bits != 16 || alignment != channels * 2 || bytesPerSecond != rate * alignment) return null;
                byteRate = bytesPerSecond;
                frameSize = alignment;
            } else if (data.AsSpan(pos,4).SequenceEqual("data"u8)) {
                if (payloadSize.HasValue || size % 2 != 0) return null;
                payloadSize = size;
            }
            var next = (long)body + size + (size % 2);
            if (next > data.Length) return null;
            pos = (int)next;
        }
        return pos == data.Length && byteRate.HasValue && payloadSize.HasValue && frameSize.HasValue && payloadSize.Value % frameSize.Value == 0
            ? (double)payloadSize.Value / byteRate.Value : null;
    }
    private static double? Duration(byte[] data, int start, int end) {
        for (var pos = start; pos <= end - 8;) {
            var size = BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan(pos,4));
            if (size < 8 || size > end - pos) return null;
            var type = Encoding.ASCII.GetString(data,pos+4,4);
            var body = pos + 8;
            if (type == "moov") { var result = Duration(data,body,pos+(int)size); if (result != null) return result; }
            if (type == "mvhd" && size >= 28) {
                var version = data[body];
                var offset = version == 1 ? 20 : 12;
                if (version > 1 || body + offset + (version == 1 ? 12 : 8) > pos + size) return null;
                var scale = BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan(body+offset,4));
                var ticks = version == 1 ? BinaryPrimitives.ReadUInt64BigEndian(data.AsSpan(body+offset+4,8)) : BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan(body+offset+4,4));
                return scale == 0 ? null : (double)ticks / scale;
            }
            pos += (int)size;
        }
        return null;
    }
}
