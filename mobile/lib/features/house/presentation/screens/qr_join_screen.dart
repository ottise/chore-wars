import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../domain/entities/invite_code.dart';
import '../providers/house_providers.dart';

class QrJoinScreen extends ConsumerStatefulWidget {
  const QrJoinScreen({super.key});
  @override
  ConsumerState<QrJoinScreen> createState() => _QrJoinScreenState();
}

class _QrJoinScreenState extends ConsumerState<QrJoinScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  Future<void> _cameraQueue = Future.value();
  bool _processing = false;
  bool _inForeground = true;
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan House QR Code'),
      actions: [
        TextButton(
          onPressed: _processing
              ? null
              : () => _camera(() => _controller.switchCamera()),
          child: const Text('Switch Camera'),
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
                onDetect: _onDetect,
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
                            onPressed: () => _camera(() => _controller.start()),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Place the full QR code inside the frame. Use good lighting and hold the camera steady.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: _processing
                      ? null
                      : () => context.pushReplacement('/houses/join'),
                  child: const Text('Enter Invite Code Instead'),
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
    final codes = capture.barcodes
        .map((b) => parseInviteCode(b.rawValue ?? ''))
        .whereType<String>();
    if (codes.isEmpty) return;
    final code = codes.first;
    setState(() => _processing = true);
    var joined = false;
    try {
      await _camera(() => _controller.stop());
      if (!mounted) return;
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
              child: const Text('Tham gia'),
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
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
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
