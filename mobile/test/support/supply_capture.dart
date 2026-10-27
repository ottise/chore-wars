import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const captureSupplies = bool.fromEnvironment('SUPPLIES_CAPTURE');
const supplyCaptureKey = ValueKey('supply-capture');

Future<void> loadSupplyCaptureFonts(WidgetTester tester) async {
  if (!captureSupplies) return;
  final loader = FontLoader('BeVietnamPro');
  for (final weight in ['Regular', 'Medium', 'SemiBold']) {
    loader.addFont(
      rootBundle.load('assets/fonts/be_vietnam_pro/BeVietnamPro-$weight.ttf'),
    );
  }
  await tester.runAsync(loader.load);
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await tester.runAsync(icons.load);
}

Future<void> captureSupplyScreen(WidgetTester tester, String name) async {
  if (!captureSupplies) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(supplyCaptureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('../artifacts/supplies/visual');
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
