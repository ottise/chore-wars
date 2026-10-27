import 'dart:async';
import 'dart:convert';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/house/presentation/screens/qr_join_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_image_decoder_test.dart' show qrImage;

class _CameraDenied extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  Completer<void>? permissionGate;
  final directions = <CameraFacing>[];
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<Never> start(dynamic options) async {
    directions.add(options.cameraDirection as CameraFacing);
    await permissionGate?.future;
    throw const MobileScannerException(
      errorCode: MobileScannerErrorCode.permissionDenied,
    );
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Picker extends ImagePicker {
  Uint8List? bytes;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    return bytes == null
        ? null
        : XFile.fromData(bytes!, name: 'invitation.png', mimeType: 'image/png');
  }
}

class _Server implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int previewStatus = 200;
  int joinStatus = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final preview = options.method == 'GET';
    expect(
      options.path,
      preview ? '/invitations/AB12CD34/preview' : '/houses/join',
    );
    final status = preview ? previewStatus : joinStatus;
    return ResponseBody.fromString(
      jsonEncode(
        status >= 400
            ? {
                'message': preview
                    ? 'Invitation not found.'
                    : 'Already a member.',
              }
            : preview
            ? {'name': 'Test house', 'activeMembers': 2, 'capacity': 6}
            : {},
      ),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MobileScannerPlatform original;
  late _CameraDenied camera;
  late _Picker picker;
  late _Server server;

  setUp(() {
    original = MobileScannerPlatform.instance;
    camera = _CameraDenied();
    MobileScannerPlatform.instance = camera;
    picker = _Picker();
    server = _Server();
  });
  tearDown(() async {
    MobileScannerPlatform.instance = original;
    await camera.captures.close();
  });

  Future<void> open(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(path: '/scan', builder: (_, _) => const QrJoinScreen()),
        GoRoute(
          path: '/houses',
          builder: (_, _) => const Scaffold(body: Text('House list')),
        ),
        GoRoute(
          path: '/houses/join',
          builder: (_, _) => const Scaffold(body: Text('Manual invite')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final dio = Dio()..httpClientAdapter = server;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          houseQrImagePickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> upload(WidgetTester tester, String value) async {
    picker.bytes = await tester.runAsync(() => qrImage(value));
    await tester.tap(find.text('Choose QR image'));
    await tester.pump();
    for (
      var i = 0;
      i < 40 &&
          find.byType(AlertDialog).evaluate().isEmpty &&
          find.text('Reading QR code…').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'QR image works with camera denied; preview cancel makes no join and retry joins once',
    (tester) async {
      await open(tester);
      expect(
        find.textContaining('Camera access is unavailable'),
        findsOneWidget,
      );
      await upload(tester, 'AB12CD34');
      expect(find.text('Join House Test house?'), findsOneWidget);
      expect(find.text('2 / 6 members'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await upload(tester, 'AB12CD34');
      await tester.tap(find.widgetWithText(FilledButton, 'Join house'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final joins = server.requests.where((r) => r.method == 'POST').toList();
      expect(joins, hasLength(1));
      expect(joins.single.data, {'inviteCode': 'AB12CD34'});
      expect(find.text('House list'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picker cancellation and unrelated QR never call the server', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Choose QR image'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(server.requests, isEmpty);
    await upload(tester, 'https://example.test/menu');
    expect(find.textContaining('not a house invitation'), findsOneWidget);
    expect(server.requests, isEmpty);
    expect(find.text('Choose QR image'), findsOneWidget);
  });

  testWidgets(
    'image preview does not wait for an unanswered camera permission prompt',
    (tester) async {
      camera.permissionGate = Completer<void>();
      await open(tester);
      expect(
        find.textContaining('Allow camera access, or choose'),
        findsOneWidget,
      );
      await upload(tester, 'AB12CD34');
      expect(find.text('Join House Test house?'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
      camera.permissionGate!.complete();
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('desktop scanner uses front camera and fits a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester);
    expect(camera.directions.first, CameraFacing.front);
    await tester.tap(find.text('Enter invite code instead'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Manual invite'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('expired invite and join rejection stay recoverable', (
    tester,
  ) async {
    server.previewStatus = 404;
    await open(tester);
    await upload(tester, 'AB12CD34');
    expect(find.textContaining('Invitation not found.'), findsOneWidget);
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    server.previewStatus = 200;
    server.joinStatus = 409;
    await upload(tester, 'AB12CD34');
    await tester.tap(find.widgetWithText(FilledButton, 'Join house'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Already a member.'), findsOneWidget);
    expect(find.text('Choose QR image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'duplicate camera captures open one preview and never auto-join',
    (tester) async {
      await open(tester);
      final capture = BarcodeCapture(
        barcodes: [const Barcode(rawValue: 'AB12CD34')],
      );
      camera.captures.add(capture);
      camera.captures.add(capture);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Join House Test house?'), findsOneWidget);
      expect(server.requests, hasLength(1));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      camera.captures.add(capture);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(server.requests, hasLength(1));
      expect(find.text('Scan again'), findsOneWidget);
      await tester.tap(find.text('Scan again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      camera.captures.add(capture);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(server.requests, hasLength(2));
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
}
