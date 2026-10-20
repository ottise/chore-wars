using System.Buffers.Binary;
using System.Text;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services;
public static class MediaInspector {
    public static (string Mime, string Type, int? Duration) Inspect(byte[] data) {
        if (data.Length == 0 || data.Length > 5 * 1024 * 1024) throw new DomainException("Media must be between 1 byte and 5 MB.");
        if (data.Length >= 8 && data.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10})) return ("image/png", "IMAGE", null);
        if (data.Length >= 3 && data[0] == 255 && data[1] == 216 && data[2] == 255) return ("image/jpeg", "IMAGE", null);
        if (data.Length >= 16 && Encoding.ASCII.GetString(data,4,4) == "ftyp") {
            var seconds = Duration(data, 0, data.Length);
            if (seconds is > 0 and <= 60 && data.AsSpan().IndexOf("mp4a"u8) >= 0) return ("audio/mp4", "AUDIO", (int)Math.Ceiling(seconds.Value));
            throw new DomainException("Voice notes must be AAC in M4A and at most 60 seconds.");
        }
        throw new DomainException("Supported media: JPEG, PNG, or AAC M4A.");
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
