import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chore_wars/features/house/domain/entities/invite_code.dart';
import 'package:chore_wars/features/house/presentation/qr_image_decoder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<Uint8List> qrImage(
  String? value, {
  bool mirror = false,
  bool rotate = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  canvas.save();
  canvas.translate(40, 40);
  if (mirror) {
    canvas.translate(240, 0);
    canvas.scale(-1, 1);
  }
  if (rotate) {
    canvas.translate(240, 0);
    canvas.rotate(1.5707963267948966);
  }
  if (value != null) {
    QrPainter(
      data: value,
      version: QrVersions.auto,
    ).paint(canvas, const Size(240, 240));
  }
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 320);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  for (final mode in ['normal', 'mirrored', 'rotated']) {
    testWidgets('decodes a real $mode invitation QR PNG', (tester) async {
      await tester.runAsync(() async {
        final image = await qrImage(
          'AB12CD34',
          mirror: mode == 'mirrored',
          rotate: mode == 'rotated',
        );
        expect(await decodeQrImage(image), 'AB12CD34');
      });
    });
  }

  testWidgets(
    'decodes an invite link but rejects unrelated QR content as an invitation',
    (tester) async {
      await tester.runAsync(() async {
        final link = await decodeQrImage(
          await qrImage('https://example.test/join?code=ab12cd34'),
        );
        expect(parseInviteCode(link), 'AB12CD34');
        final unrelated = await decodeQrImage(
          await qrImage('https://example.test/menu'),
        );
        expect(parseInviteCode(unrelated), isNull);
      });
    },
  );

  testWidgets(
    'reports a clear error for an image with no QR and corrupt bytes',
    (tester) async {
      await tester.runAsync(() async {
        await expectLater(
          decodeQrImage(await qrImage(null)),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('No readable QR'),
            ),
          ),
        );
        await expectLater(
          decodeQrImage(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          decodeQrImage(Uint8List(maxQrImageBytes + 1)),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('10 MB'),
            ),
          ),
        );
      });
    },
  );
}
