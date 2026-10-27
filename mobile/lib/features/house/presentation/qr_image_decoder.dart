import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:zxing2/qrcode.dart';

const maxQrImageBytes = 10 * 1024 * 1024;
const _maxDecodeDimension = 1600;

Future<String> decodeQrImage(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > maxQrImageBytes) {
    throw const FormatException('Choose a QR image smaller than 10 MB.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final scale = math.min(
      1.0,
      _maxDecodeDimension / math.max(descriptor.width, descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    image = (await codec.getNextFrame()).image;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) throw const FormatException('Unable to read this image.');
    return await compute(_decodePixels, (
      image.width,
      image.height,
      rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
    ));
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'Unable to read this image. Choose a PNG, JPG or WebP image.',
    );
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

String _decodePixels((int, int, Uint8List) input) {
  final (width, height, rgba) = input;
  final pixels = Int32List(width * height);
  for (var i = 0; i < pixels.length; i++) {
    final offset = i * 4;
    final alpha = rgba[offset + 3];
    // Composite transparent QR margins on white before calculating luminance.
    final r = (rgba[offset] * alpha + 255 * (255 - alpha)) ~/ 255;
    final g = (rgba[offset + 1] * alpha + 255 * (255 - alpha)) ~/ 255;
    final b = (rgba[offset + 2] * alpha + 255 * (255 - alpha)) ~/ 255;
    pixels[i] = (r << 16) | (g << 8) | b;
  }
  final source = RGBLuminanceSource(width, height, pixels);
  for (final candidate in [source, source.invert()]) {
    try {
      return QRCodeReader()
          .decode(
            BinaryBitmap(HybridBinarizer(candidate)),
            hints: DecodeHints()..put(DecodeHintType.tryHarder),
          )
          .text;
    } on ReaderException {
      // Also try light QR modules on a dark background.
    }
  }
  throw const FormatException(
    'No readable QR code found. Choose a clear image with the entire code and its border.',
  );
}
