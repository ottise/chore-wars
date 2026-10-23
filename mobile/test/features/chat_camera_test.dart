import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:chore_wars/features/chat/presentation/widgets/message_input.dart';
import 'package:chore_wars/features/ai/presentation/ai_evidence_screen.dart';
import 'package:chore_wars/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Camera extends CameraPlatform {
  int captures = 0;
  int disposals = 0;
  bool deny = false;
  Uint8List? photoBytes;
  final errors = StreamController<CameraErrorEvent>.broadcast();
  @override
  Future<List<CameraDescription>> availableCameras() async {
    if (deny) throw CameraException('CameraAccessDenied', 'Denied');
    return [
      const CameraDescription(
        name: 'test',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 0,
      ),
    ];
  }

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async => 1;
  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => errors.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Widget buildPreview(int cameraId) => const SizedBox(width: 640, height: 480);
  @override
  Future<XFile> takePicture(int cameraId) async {
    captures++;
    return XFile.fromData(
      photoBytes ?? Uint8List.fromList([255, 216, 255, 1]),
      name: 'photo.jpg',
      path: 'photo.jpg',
    );
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposals++;
  }
}

void main() {
  late _Camera camera;
  late CameraPlatform previous;
  setUp(() {
    previous = CameraPlatform.instance;
    CameraPlatform.instance = camera = _Camera();
  });
  tearDown(() => CameraPlatform.instance = previous);

  testWidgets(
    'evidence camera opens preview and returns photo without completing chore',
    (tester) async {
      camera.photoBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final requests = <String>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request.path);
              handler.reject(DioException(requestOptions: request));
            },
          ),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(
            home: AiEvidenceScreen(occurrenceId: 'chore'),
          ),
        ),
      );
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Capture Photo Evidence'), findsOneWidget);
      expect(camera.captures, 0);
      await tester.tap(find.text('Use This Photo'));
      await tester.pumpAndSettle();
      expect(camera.captures, 1);
      expect(camera.disposals, 1);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Complete with This Photo'), findsOneWidget);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('denied evidence camera returns without selecting a photo', (
    tester,
  ) async {
    camera.deny = true;
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AiEvidenceScreen(occurrenceId: 'chore')),
      ),
    );
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check camera permissions'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(camera.captures, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture immediately sends bytes; retry reuses the same photo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(354, 643);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var sends = 0;
    final payloads = <List<int>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MessageInput(
              onSendMessage: (_) async {},
              onSendImage: (bytes, name) async {
                sends++;
                payloads.add(bytes);
                expect(name, 'photo.jpg');
                if (sends == 1) throw StateError('Lost response');
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Take Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture & Send'));
    await tester.pumpAndSettle();
    expect(sends, 1);
    expect(find.text('Unable to send photo.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(sends, 2);
    expect(payloads[0], payloads[1]);
    expect(camera.captures, 1);
    expect(camera.disposals, 1);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('denied camera can close without uploading', (tester) async {
    camera.deny = true;
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageInput(
            onSendMessage: (_) async {},
            onSendImage: (_, _) async {
              sends++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Take Photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check camera permissions'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(sends, 0);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Take Photo'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
