import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/widgets/app_states.dart';
import '../providers/house_providers.dart';
import '../../../../core/utils/api_error_message.dart';


/// Camera-based QR scanner that reads the invite code and calls joinHouse.
class QrJoinScreen extends ConsumerStatefulWidget {
  const QrJoinScreen({super.key});

  @override
  ConsumerState<QrJoinScreen> createState() => _QrJoinScreenState();
}

class _QrJoinScreenState extends ConsumerState<QrJoinScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR code'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Flip camera',
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          _ScanOverlay(),
          if (_processing)
            const ColoredBox(
              color: Colors.black54,
              child: LoadingView(),
            ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      await ref.read(houseRepositoryProvider).joinHouse(
        inviteCode: rawValue.trim().toUpperCase(),
      );
      refreshHouseState(ref);
      if (mounted) {
        showAppMessage(context, 'Joined house successfully!');
        context.go('/houses');
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, apiErrorMessage(error), error: true);
        await _controller.start();
        setState(() => _processing = false);
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
            top: top ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            bottom: top ? BorderSide.none : const BorderSide(color: Colors.white, width: 4),
            left: left ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            right: left ? BorderSide.none : const BorderSide(color: Colors.white, width: 4),
          ),
        ),
      ),
    );
  }
}
