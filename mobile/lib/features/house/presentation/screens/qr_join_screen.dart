import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_page_frame.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../domain/entities/invite_code.dart';
import '../providers/house_providers.dart';
import '../qr_image_decoder.dart';

final houseQrImagePickerProvider = Provider<ImagePicker>(
  (ref) => ImagePicker(),
);

class QrJoinScreen extends ConsumerStatefulWidget {
  const QrJoinScreen({super.key});
  @override
  ConsumerState<QrJoinScreen> createState() => _QrJoinScreenState();
}

class _QrJoinScreenState extends ConsumerState<QrJoinScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    facing: switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => CameraFacing.front,
      _ => CameraFacing.back,
    },
    cameraResolution: const Size(1280, 720),
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  Future<void> _cameraQueue = Future.value();
  bool _processing = false;
  bool _inForeground = true;
  String? _error;
  String? _lastDetectedValue;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _camera(() => _controller.start()),
    );
  }

  Future<void> _camera(Future<void> Function() action) {
    _cameraQueue = _cameraQueue.then((_) async {
      if (!mounted) return;
      try {
        await action();
      } catch (_) {
        if (mounted) {
          showAppMessage(
            context,
            'Unable to open camera. Check camera permissions or enter an invite code.',
            error: true,
          );
        }
      }
    });
    return _cameraQueue;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _inForeground = false;
      unawaited(_camera(() => _controller.stop()));
    } else if (state == AppLifecycleState.resumed) {
      _inForeground = true;
      if (!_processing) unawaited(_camera(() => _controller.start()));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraQueue.then((_) => _controller.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPageFrame(builder: _buildScreen);

  Widget _buildScreen(BuildContext context) => Scaffold(
    appBar: AppPageBar(
      title: 'Scan house QR code',
      actions: [
        IconButton(
          tooltip: 'Switch camera',
          onPressed: _processing
              ? null
              : () => _camera(() => _controller.switchCamera()),
          icon: const Icon(Icons.cameraswitch_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                fit: BoxFit.contain,
                onDetect: _onDetect,
                placeholderBuilder: (context, child) => ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Allow camera access, or choose a QR image below.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                errorBuilder: (context, error, child) => ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Camera access is unavailable. Allow camera access for this app or browser.',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _processing
                                ? null
                                : () => _camera(() => _controller.start()),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                overlayBuilder: (context, constraints) =>
                    IgnorePointer(child: _ScanOverlay()),
              ),
              if (_processing)
                const ColoredBox(color: Colors.black54, child: LoadingView()),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Show the entire QR code to your camera. On a computer, you can also choose a saved QR image.',
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _processing ? null : _pickQrImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _processing ? 'Reading QR code…' : 'Choose QR image',
                    ),
                  ),
                ),
                if (_lastDetectedValue != null)
                  TextButton(
                    onPressed: _processing
                        ? null
                        : () {
                            setState(() {
                              _lastDetectedValue = null;
                              _error = null;
                            });
                            unawaited(_camera(() => _controller.start()));
                          },
                    child: const Text('Scan again'),
                  ),
                TextButton(
                  onPressed: _processing
                      ? null
                      : () => context.pushReplacement('/houses/join'),
                  child: const Text('Enter invite code instead'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || !_inForeground) return;
    final values = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    if (values.isEmpty) return;
    final raw = values.firstWhere(
      (value) => parseInviteCode(value) != null,
      orElse: () => values.first,
    );
    if (raw == _lastDetectedValue) return;
    _lastDetectedValue = raw;
    await _processQr(() async => raw);
  }

  Future<void> _pickQrImage() {
    if (_processing) return Future.value();
    // Open the browser picker during the click gesture, before stopping camera.
    final selected = ref
        .read(houseQrImagePickerProvider)
        .pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    return _processQr(() async {
      final image = await selected;
      if (image == null) return null;
      if (await image.length() > maxQrImageBytes) {
        throw const FormatException('Choose a QR image smaller than 10 MB.');
      }
      return decodeQrImage(await image.readAsBytes());
    });
  }

  Future<void> _processQr(Future<String?> Function() read) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    var joined = false;
    try {
      // A pending camera permission prompt must not block importing an image.
      unawaited(_camera(() => _controller.stop()));
      if (!mounted) return;
      final raw = await read();
      if (!mounted || raw == null) return;
      final code = parseInviteCode(raw);
      if (code == null) {
        throw const FormatException(
          'This QR code is not a house invitation. Ask your housemate for the house QR code.',
        );
      }
      final preview = await ref
          .read(dioProvider)
          .get('/invitations/${Uri.encodeComponent(code)}/preview');
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Join House ${preview.data['name']}?'),
          content: Text(
            '${preview.data['activeMembers']} / ${preview.data['capacity']} members',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Join house'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref.read(houseRepositoryProvider).joinHouse(inviteCode: code);
      if (!mounted) return;
      refreshHouseState(ref);
      showAppMessage(context, 'Joined house');
      joined = true;
      context.go('/houses');
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : apiErrorMessage(error),
        );
      }
    } finally {
      if (mounted && !joined) {
        setState(() => _processing = false);
        if (_inForeground) await _camera(() => _controller.start());
      }
    }
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            _Corner(top: true, left: true),
            _Corner(top: true, left: false),
            _Corner(top: false, left: true),
            _Corner(top: false, left: false),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.top, required this.left});
  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            bottom: top
                ? BorderSide.none
                : const BorderSide(color: Colors.white, width: 4),
            left: left
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            right: left
                ? BorderSide.none
                : const BorderSide(color: Colors.white, width: 4),
          ),
        ),
      ),
    );
  }
}
